-- Optional company on orders

alter table public.orders
  add column if not exists company text;

-- Refresh order_summary so o.* includes company
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
