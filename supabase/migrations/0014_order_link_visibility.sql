-- Link rules:
--   admin   = admin only (no partner commission)
--   richard = Richard & admin (Richard R20)
--   delton  = Delton & admin (Delton R15)
-- Partners can SELECT any order linked to them (by order_type), not only created_by.

-- Commission trigger: only pay the linked partner
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

  if new.order_type = 'delton' then
    select u.id into delton_id
    from public.users u
    where lower(u.name) = 'delton'
    limit 1;

    if delton_id is not null then
      insert into public.order_splits (order_id, user_id, amount)
      values (new.id, delton_id, 15.00);
    end if;
  elsif new.order_type = 'richard' then
    select u.id into richard_id
    from public.users u
    where lower(u.name) = 'richard'
    limit 1;

    if richard_id is not null then
      insert into public.order_splits (order_id, user_id, amount)
      values (new.id, richard_id, 20.00);
    end if;
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

  if typ = 'delton' then
    select u.id into delton_id
    from public.users u
    where lower(u.name) = 'delton'
    limit 1;

    if delton_id is not null then
      insert into public.order_splits (order_id, user_id, amount)
      values (anchor_id, delton_id, 15.00);
    end if;
  elsif typ = 'richard' then
    select u.id into richard_id
    from public.users u
    where lower(u.name) = 'richard'
    limit 1;

    if richard_id is not null then
      insert into public.order_splits (order_id, user_id, amount)
      values (anchor_id, richard_id, 20.00);
    end if;
  end if;

  return new;
end;
$$;

-- Rebuild splits under link-based commissions
delete from public.order_splits;

insert into public.order_splits (order_id, user_id, amount)
select
  g.anchor_id,
  u.id,
  15.00
from (
  select distinct on (o.order_group_id)
    o.order_group_id,
    o.id as anchor_id,
    o.order_type
  from public.orders o
  order by o.order_group_id, o.created_at, o.id
) g
join public.users u on lower(u.name) = 'delton'
where g.order_type = 'delton';

insert into public.order_splits (order_id, user_id, amount)
select
  g.anchor_id,
  u.id,
  20.00
from (
  select distinct on (o.order_group_id)
    o.order_group_id,
    o.id as anchor_id,
    o.order_type
  from public.orders o
  order by o.order_group_id, o.created_at, o.id
) g
join public.users u on lower(u.name) = 'richard'
where g.order_type = 'richard';

-- Partners see orders linked to them (whole group), not only created_by / split on one line
-- IMPORTANT: never query public.orders inside this policy (causes infinite recursion)
drop policy if exists "orders_select" on public.orders;

create policy "orders_select"
  on public.orders for select to authenticated
  using (
    private.is_admin()
    or created_by = private.partner_id()
    or (
      order_type = 'delton'
      and exists (
        select 1 from public.users u
        where u.id = private.partner_id()
          and lower(u.name) = 'delton'
      )
    )
    or (
      order_type = 'richard'
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

-- Status changes allowed for linked partner (creator or matching link)
create or replace function public.set_order_status(
  p_order_id uuid,
  p_status text
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.orders;
  me uuid := private.partner_id();
  me_name text;
  grp uuid;
  typ text;
begin
  if p_status is null or p_status not in ('pending', 'paid', 'cancelled') then
    raise exception 'Invalid status';
  end if;

  if me is null then
    raise exception 'Not linked to a partner';
  end if;

  select lower(u.name) into me_name
  from public.users u
  where u.id = me;

  select o.order_group_id, o.order_type into grp, typ
  from public.orders o
  where o.id = p_order_id;

  if grp is null then
    raise exception 'Order not found';
  end if;

  if not (
    private.is_admin()
    or exists (
      select 1
      from public.orders o
      where o.order_group_id = grp
        and o.created_by = me
    )
    or (typ = 'delton' and me_name = 'delton')
    or (typ = 'richard' and me_name = 'richard')
  ) then
    raise exception 'Not allowed to update this order';
  end if;

  update public.orders
  set status = p_status
  where order_group_id = grp;

  select * into result
  from public.orders
  where id = p_order_id;

  return result;
end;
$$;

revoke all on function public.set_order_status(uuid, text) from public;
grant execute on function public.set_order_status(uuid, text) to authenticated;
