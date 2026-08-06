-- Catch-up: company column + rename delivery_date → date_paid + unit cost trigger
-- (0004/0005 existed in repo but were never applied to the remote project)

drop view if exists public.order_summary;

alter table public.orders
  add column if not exists company text;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'delivery_date'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'orders'
      and column_name = 'date_paid'
  ) then
    alter table public.orders rename column delivery_date to date_paid;
  end if;
end $$;

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

create or replace function public.set_order_unit_cost_from_product()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  product_cost numeric(10, 2);
begin
  if new.is_bulk is distinct from true then
    select cost_price into product_cost
    from public.products
    where id = new.product_id;

    if product_cost is null then
      raise exception 'Product not found';
    end if;

    new.unit_cost := product_cost;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_set_unit_cost on public.orders;

create trigger trg_orders_set_unit_cost
  before insert on public.orders
  for each row
  execute function public.set_order_unit_cost_from_product();

revoke all on function public.set_order_unit_cost_from_product() from public;
