-- Rename order_type 'both' -> 'all'
-- Labels: All, Delton, Richard, Admin (admin is always linked)

update public.orders
set order_type = 'all'
where order_type = 'both';

alter table public.orders
  drop constraint if exists orders_order_type_check;

alter table public.orders
  add constraint orders_order_type_check
  check (order_type in ('admin', 'delton', 'richard', 'all'));

create or replace function public.set_order_type_default()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  partner_name text;
begin
  if private.is_admin() then
    if new.order_type is null
      or new.order_type not in ('admin', 'delton', 'richard', 'all') then
      new.order_type := 'admin';
    end if;
  else
    select lower(u.name) into partner_name
    from public.users u
    where u.id = private.partner_id();

    if partner_name = 'richard' then
      new.order_type := 'richard';
    elsif partner_name = 'delton' then
      new.order_type := 'delton';
    else
      new.order_type := 'admin';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.create_order_splits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  delton_id uuid;
  richard_id uuid;
begin
  if exists (
    select 1
    from public.orders o
    join public.order_splits s on s.order_id = o.id
    where o.order_group_id = new.order_group_id
  ) then
    return new;
  end if;

  select u.id into delton_id
  from public.users u
  where lower(u.name) = 'delton'
  limit 1;

  select u.id into richard_id
  from public.users u
  where lower(u.name) = 'richard'
  limit 1;

  if new.order_type in ('admin', 'delton', 'all') and delton_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (new.id, delton_id, 15.00);
  end if;

  if new.order_type in ('richard', 'all') and richard_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (new.id, richard_id, 20.00);
  end if;

  return new;
end;
$$;

create or replace function public.update_order_splits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  anchor_id uuid;
  delton_id uuid;
  richard_id uuid;
  grp uuid := new.order_group_id;
  typ text := new.order_type;
begin
  if new.order_type is not distinct from old.order_type then
    return new;
  end if;

  if pg_trigger_depth() > 1 then
    return new;
  end if;

  update public.orders
  set order_type = typ
  where order_group_id = grp
    and id <> new.id
    and order_type is distinct from typ;

  delete from public.order_splits s
  using public.orders o
  where s.order_id = o.id
    and o.order_group_id = grp;

  select o.id into anchor_id
  from public.orders o
  where o.order_group_id = grp
  order by o.created_at, o.id
  limit 1;

  if anchor_id is null then
    return new;
  end if;

  select u.id into delton_id
  from public.users u
  where lower(u.name) = 'delton'
  limit 1;

  select u.id into richard_id
  from public.users u
  where lower(u.name) = 'richard'
  limit 1;

  if typ in ('admin', 'delton', 'all') and delton_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (anchor_id, delton_id, 15.00);
  end if;

  if typ in ('richard', 'all') and richard_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (anchor_id, richard_id, 20.00);
  end if;

  return new;
end;
$$;

drop policy if exists "orders_select" on public.orders;

create policy "orders_select"
  on public.orders for select to authenticated
  using (
    private.is_admin()
    or created_by = private.partner_id()
    or (
      order_type in ('admin', 'delton', 'all')
      and exists (
        select 1 from public.users u
        where u.id = private.partner_id()
          and lower(u.name) = 'delton'
      )
    )
    or (
      order_type in ('richard', 'all')
      and exists (
        select 1 from public.users u
        where u.id = private.partner_id()
          and lower(u.name) = 'richard'
      )
    )
    or exists (
      select 1
      from public.order_splits s
      where s.order_id = orders.id
        and s.user_id = private.partner_id()
    )
  );

create or replace function private.can_manage_order(p_order_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := private.partner_id();
  me_name text;
  grp uuid;
  typ text;
begin
  if me is null then
    return false;
  end if;

  if private.is_admin() then
    return true;
  end if;

  select lower(u.name) into me_name
  from public.users u
  where u.id = me;

  select o.order_group_id, o.order_type into grp, typ
  from public.orders o
  where o.id = p_order_id;

  if grp is null then
    return false;
  end if;

  return exists (
    select 1
    from public.orders o
    where o.order_group_id = grp
      and o.created_by = me
  )
  or (
    me_name = 'delton'
    and typ in ('admin', 'delton', 'all')
  )
  or (
    me_name = 'richard'
    and typ in ('richard', 'all')
  );
end;
$$;
