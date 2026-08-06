-- Rename delivery_date → date_paid
-- Auto-fill unit_cost from current product on insert (unless bulk override)
-- Partners may create orders; product list readable by all linked partners

-- ---------------------------------------------------------------------------
-- date_paid
-- ---------------------------------------------------------------------------

alter table public.orders rename column delivery_date to date_paid;

-- Recreate order_summary so it picks up the renamed column via o.*
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

-- ---------------------------------------------------------------------------
-- On insert: always snapshot unit_cost from product unless is_bulk
-- (form no longer requires users to enter cost)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- RLS: partners can read active products (for order form) and create orders
-- ---------------------------------------------------------------------------

drop policy if exists "products_select_admin" on public.products;
drop policy if exists "products_select" on public.products;

create policy "products_select"
  on public.products for select to authenticated
  using (private.is_admin() or private.partner_id() is not null);

drop policy if exists "orders_insert_admin" on public.orders;
drop policy if exists "orders_insert" on public.orders;

create policy "orders_insert"
  on public.orders for insert to authenticated
  with check (private.is_admin() or private.partner_id() is not null);

-- Partners may read orders they have a split on (needed after create / detail).
-- Unit cost is hidden in the UI for non-admins.
drop policy if exists "orders_select_admin" on public.orders;
drop policy if exists "orders_select" on public.orders;

create policy "orders_select"
  on public.orders for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1
      from public.order_splits s
      where s.order_id = orders.id
        and s.user_id = private.partner_id()
    )
  );
