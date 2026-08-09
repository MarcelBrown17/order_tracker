-- Fixed partner commissions:
--   Delton: R15 on every order group
--   Richard: R20 only on richard-attributed orders
-- Admin selects order_type; partners are forced to their own type.

alter table public.orders
  add column if not exists order_type text;

-- Backfill from creator name (fallback admin)
update public.orders o
set order_type = case lower(u.name)
  when 'richard' then 'richard'
  when 'delton' then 'delton'
  else 'admin'
end
from public.users u
where o.created_by = u.id
  and o.order_type is null;

update public.orders
set order_type = 'admin'
where order_type is null;

alter table public.orders
  alter column order_type set default 'admin',
  alter column order_type set not null;

alter table public.orders
  drop constraint if exists orders_order_type_check;

alter table public.orders
  add constraint orders_order_type_check
  check (order_type in ('admin', 'delton', 'richard'));

create index if not exists orders_order_type_idx
  on public.orders (order_type);

-- Force partner order_type from their name; admin may choose
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
    if new.order_type is null or new.order_type not in ('admin', 'delton', 'richard') then
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

drop trigger if exists trg_orders_set_order_type on public.orders;

create trigger trg_orders_set_order_type
  before insert or update of order_type on public.orders
  for each row
  execute function public.set_order_type_default();

revoke all on function public.set_order_type_default() from public;

-- Create Delton/Richard commission rows once per order group
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

  if delton_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (new.id, delton_id, 15.00);
  end if;

  if new.order_type = 'richard' and richard_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (new.id, richard_id, 20.00);
  end if;

  return new;
end;
$$;

-- Fixed commissions: only rebuild when order_type changes
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

  -- Avoid recursive rebuild when syncing sibling lines
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  -- Keep all lines in the group on the same type
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

  if delton_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (anchor_id, delton_id, 15.00);
  end if;

  if typ = 'richard' and richard_id is not null then
    insert into public.order_splits (order_id, user_id, amount)
    values (anchor_id, richard_id, 20.00);
  end if;

  return new;
end;
$$;

drop view if exists public.order_summary;

create view public.order_summary
with (security_invoker = true)
as
select
  o.*,
  p.name as product_name,
  (o.unit_sell_price - o.unit_cost) * o.quantity as profit_total
from public.orders o
join public.products p on p.id = o.product_id;

grant select on public.order_summary to authenticated;

-- Rebuild existing splits under the new rules (once per group)
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
join public.users u on lower(u.name) = 'delton';

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
