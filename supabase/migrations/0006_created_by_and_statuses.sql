-- Track which partner created each order; partners list only their own on Orders
-- Simplify order status to pending / paid / cancelled

-- ---------------------------------------------------------------------------
-- created_by
-- ---------------------------------------------------------------------------

alter table public.orders
  add column if not exists created_by uuid references public.users (id);

create or replace function public.set_order_created_by()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is null then
    new.created_by := private.partner_id();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_set_created_by on public.orders;

create trigger trg_orders_set_created_by
  before insert on public.orders
  for each row
  execute function public.set_order_created_by();

revoke all on function public.set_order_created_by() from public;

-- ---------------------------------------------------------------------------
-- Status: map delivered → paid, tighten check
-- ---------------------------------------------------------------------------

update public.orders
set status = 'paid'
where status = 'delivered';

alter table public.orders drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check
  check (status in ('pending', 'paid', 'cancelled'));

-- ---------------------------------------------------------------------------
-- Refresh order_summary so o.* includes created_by
-- ---------------------------------------------------------------------------

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
