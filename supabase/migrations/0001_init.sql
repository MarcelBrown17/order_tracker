-- Biscuit Order Tracker — initial schema
-- Run this in the Supabase SQL Editor (or via supabase db push)

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  cost_price numeric(10, 2) not null,
  sell_price numeric(10, 2) not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  company text,
  customer_contact text,
  product_id uuid not null references public.products (id),
  quantity int not null default 1 check (quantity > 0),
  unit_cost numeric(10, 2) not null,
  unit_sell_price numeric(10, 2) not null,
  is_bulk boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'delivered', 'cancelled')),
  order_date date not null default current_date,
  date_paid date,
  notes text,
  created_at timestamptz not null default now()
);

create table public.order_splits (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  user_id uuid not null references public.users (id),
  amount numeric(10, 2) not null,
  paid_out boolean not null default false,
  created_at timestamptz not null default now(),
  unique (order_id, user_id)
);

-- ---------------------------------------------------------------------------
-- View (security_invoker so RLS on underlying tables applies)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Trigger: create 3 partner splits on order insert
-- ---------------------------------------------------------------------------

create or replace function public.create_order_splits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  split_amount numeric(10, 2);
begin
  split_amount := round(
    ((new.unit_sell_price - new.unit_cost) * new.quantity) / 3,
    2
  );

  insert into public.order_splits (order_id, user_id, amount)
  select new.id, u.id, split_amount
  from public.users u;

  return new;
end;
$$;

create trigger trg_orders_create_splits
  after insert on public.orders
  for each row
  execute function public.create_order_splits();

-- Recalculate split amounts when cost / sell / qty change (preserve paid_out)
create or replace function public.update_order_splits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  split_amount numeric(10, 2);
begin
  if (
    new.unit_cost is distinct from old.unit_cost
    or new.unit_sell_price is distinct from old.unit_sell_price
    or new.quantity is distinct from old.quantity
  ) then
    split_amount := round(
      ((new.unit_sell_price - new.unit_cost) * new.quantity) / 3,
      2
    );

    update public.order_splits
    set amount = split_amount
    where order_id = new.id;
  end if;

  return new;
end;
$$;

create trigger trg_orders_update_splits
  after update on public.orders
  for each row
  execute function public.update_order_splits();

revoke all on function public.create_order_splits() from public;
revoke all on function public.update_order_splits() from public;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_splits enable row level security;

create policy "Authenticated full access on users"
  on public.users for all to authenticated
  using (true) with check (true);

create policy "Authenticated full access on products"
  on public.products for all to authenticated
  using (true) with check (true);

create policy "Authenticated full access on orders"
  on public.orders for all to authenticated
  using (true) with check (true);

create policy "Authenticated full access on order_splits"
  on public.order_splits for all to authenticated
  using (true) with check (true);

grant select on public.order_summary to authenticated;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------------------

insert into public.users (name) values
  ('Marcel'),
  ('Delton'),
  ('Richard');

insert into public.products (name, cost_price, sell_price) values
  ('Normal Mix with Hertzoggie', 80.00, 140.00),
  ('Special Chocolate Butter Mix', 80.00, 140.00),
  ('Hertzoggie', 80.00, 140.00),
  ('Choc Crust', 80.00, 140.00),
  ('Normal Mix', 80.00, 140.00),
  ('Half Butter / Half Normal Mix', 80.00, 140.00),
  ('Butter Mix', 80.00, 140.00),
  ('Half Romaney / Half Choc Crust', 80.00, 140.00),
  ('Romaney Creams', 80.00, 140.00);
