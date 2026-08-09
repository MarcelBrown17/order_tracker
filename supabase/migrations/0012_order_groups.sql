-- Group multiple product lines into one customer order (same order_group_id)

alter table public.orders
  add column if not exists order_group_id uuid;

update public.orders
set order_group_id = id
where order_group_id is null;

alter table public.orders
  alter column order_group_id set not null;

create index if not exists orders_order_group_id_idx
  on public.orders (order_group_id);

-- Default: single-line orders are their own group (id matches group after insert)
create or replace function public.set_order_group_id_default()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_group_id is null then
    new.order_group_id := gen_random_uuid();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_set_order_group on public.orders;

create trigger trg_orders_set_order_group
  before insert on public.orders
  for each row
  execute function public.set_order_group_id_default();

revoke all on function public.set_order_group_id_default() from public;

drop view if exists public.order_summary;

create view public.order_summary
with (security_invoker = true)
as
select
  o.*,
  p.name as product_name,
  (o.unit_sell_price - o.unit_cost) * o.quantity as profit_total,
  ((o.unit_sell_price - o.unit_cost) * o.quantity) / 3 as profit_per_partner
from public.orders o
join public.products p on p.id = o.product_id;

grant select on public.order_summary to authenticated;

-- Status change applies to every line in the group
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
  grp uuid;
begin
  if p_status is null or p_status not in ('pending', 'paid', 'cancelled') then
    raise exception 'Invalid status';
  end if;

  if me is null then
    raise exception 'Not linked to a partner';
  end if;

  select order_group_id into grp
  from public.orders
  where id = p_order_id;

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
