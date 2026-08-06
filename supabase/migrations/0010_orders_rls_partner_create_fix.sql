-- Single clear RLS model for orders:
-- - Any linked partner (incl. admin) can INSERT
-- - SELECT: own created orders OR orders they have a split on
--   (split path is required for my_splits + insert().select() RETURNING)
-- - UPDATE/DELETE: admin only

drop policy if exists "orders_select" on public.orders;
drop policy if exists "orders_select_admin" on public.orders;
drop policy if exists "orders_insert" on public.orders;
drop policy if exists "orders_insert_admin" on public.orders;
drop policy if exists "orders_update_admin" on public.orders;
drop policy if exists "orders_delete_admin" on public.orders;

create policy "orders_select"
  on public.orders for select to authenticated
  using (
    private.is_admin()
    or created_by = private.partner_id()
    or exists (
      select 1
      from public.order_splits s
      where s.order_id = orders.id
        and s.user_id = private.partner_id()
    )
  );

create policy "orders_insert"
  on public.orders for insert to authenticated
  with check (
    private.partner_id() is not null
    and (
      created_by is null
      or created_by = private.partner_id()
    )
  );

create policy "orders_update_admin"
  on public.orders for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy "orders_delete_admin"
  on public.orders for delete to authenticated
  using (private.is_admin());
