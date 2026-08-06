-- Roles + RLS: Marcel is admin; partners only see their own splits/earnings
-- Safe to re-run. Run after 0001_init.sql

-- ---------------------------------------------------------------------------
-- Partner identity (one column at a time — avoids ALTER failures)
-- ---------------------------------------------------------------------------

alter table public.users
  add column if not exists auth_user_id uuid;

alter table public.users
  add column if not exists is_admin boolean not null default false;

alter table public.users
  add column if not exists email text;

-- Unique + FK (ignore if they already exist)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'users_auth_user_id_key'
  ) then
    alter table public.users
      add constraint users_auth_user_id_key unique (auth_user_id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'users_auth_user_id_fkey'
  ) then
    alter table public.users
      add constraint users_auth_user_id_fkey
      foreign key (auth_user_id) references auth.users (id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'users_email_key'
  ) then
    alter table public.users
      add constraint users_email_key unique (email);
  end if;
end $$;

update public.users
set
  is_admin = true,
  email = 'marcelbrown413@gmail.com'
where name = 'Marcel';

update public.users set is_admin = false where name <> 'Marcel';

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create schema if not exists private;

-- Match by auth_user_id OR (unlinked) login email so admin works on first sign-in
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select u.is_admin
      from public.users u
      where u.auth_user_id = auth.uid()
         or (
           u.auth_user_id is null
           and u.email is not null
           and lower(u.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
         )
      order by u.auth_user_id nulls last
      limit 1
    ),
    false
  );
$$;

create or replace function private.partner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select u.id
  from public.users u
  where u.auth_user_id = auth.uid()
     or (
       u.auth_user_id is null
       and u.email is not null
       and lower(u.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
     )
  order by u.auth_user_id nulls last
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select private.is_admin();
$$;

create or replace function public.current_partner_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select private.partner_id();
$$;

revoke all on function private.is_admin() from public;
revoke all on function private.partner_id() from public;

-- Policies + my_splits call the private helpers directly — authenticated must execute them
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.partner_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.current_partner_id() to authenticated;

-- ---------------------------------------------------------------------------
-- Partner earnings view
-- ---------------------------------------------------------------------------

drop view if exists public.my_splits;

create view public.my_splits as
select
  s.id,
  s.order_id,
  s.user_id,
  s.amount,
  s.paid_out,
  s.created_at,
  o.order_date,
  o.customer_name,
  o.status as order_status,
  o.quantity,
  p.name as product_name
from public.order_splits s
join public.orders o on o.id = s.order_id
join public.products p on p.id = o.product_id
where s.user_id = private.partner_id();

grant select on public.my_splits to authenticated;

-- ---------------------------------------------------------------------------
-- RLS policies (drop old + new so this file is re-runnable)
-- ---------------------------------------------------------------------------

drop policy if exists "Authenticated full access on users" on public.users;
drop policy if exists "Authenticated full access on products" on public.products;
drop policy if exists "Authenticated full access on orders" on public.orders;
drop policy if exists "Authenticated full access on order_splits" on public.order_splits;

drop policy if exists "users_select" on public.users;
drop policy if exists "users_insert_admin" on public.users;
drop policy if exists "users_update" on public.users;
drop policy if exists "users_delete_admin" on public.users;

drop policy if exists "products_select" on public.products;
drop policy if exists "products_select_admin" on public.products;
drop policy if exists "products_write_admin" on public.products;
drop policy if exists "products_update_admin" on public.products;
drop policy if exists "products_delete_admin" on public.products;

drop policy if exists "orders_select" on public.orders;
drop policy if exists "orders_select_admin" on public.orders;
drop policy if exists "orders_insert_admin" on public.orders;
drop policy if exists "orders_update_admin" on public.orders;
drop policy if exists "orders_delete_admin" on public.orders;

drop policy if exists "splits_select" on public.order_splits;
drop policy if exists "splits_insert_admin" on public.order_splits;
drop policy if exists "splits_update_admin" on public.order_splits;
drop policy if exists "splits_delete_admin" on public.order_splits;

-- users
create policy "users_select"
  on public.users for select to authenticated
  using (
    private.is_admin()
    or auth_user_id = auth.uid()
    or (
      auth_user_id is null
      and email is not null
      and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

create policy "users_insert_admin"
  on public.users for insert to authenticated
  with check (private.is_admin());

create policy "users_update"
  on public.users for update to authenticated
  using (
    private.is_admin()
    or auth_user_id = auth.uid()
    or (
      auth_user_id is null
      and email is not null
      and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  )
  with check (
    private.is_admin()
    or auth_user_id = auth.uid()
  );

create policy "users_delete_admin"
  on public.users for delete to authenticated
  using (private.is_admin());

-- products (admin only)
create policy "products_select_admin"
  on public.products for select to authenticated
  using (private.is_admin());

create policy "products_write_admin"
  on public.products for insert to authenticated
  with check (private.is_admin());

create policy "products_update_admin"
  on public.products for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy "products_delete_admin"
  on public.products for delete to authenticated
  using (private.is_admin());

-- orders (admin only)
create policy "orders_select_admin"
  on public.orders for select to authenticated
  using (private.is_admin());

create policy "orders_insert_admin"
  on public.orders for insert to authenticated
  with check (private.is_admin());

create policy "orders_update_admin"
  on public.orders for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy "orders_delete_admin"
  on public.orders for delete to authenticated
  using (private.is_admin());

-- order_splits
create policy "splits_select"
  on public.order_splits for select to authenticated
  using (
    private.is_admin()
    or user_id = private.partner_id()
  );

create policy "splits_insert_admin"
  on public.order_splits for insert to authenticated
  with check (private.is_admin());

create policy "splits_update_admin"
  on public.order_splits for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy "splits_delete_admin"
  on public.order_splits for delete to authenticated
  using (private.is_admin());
