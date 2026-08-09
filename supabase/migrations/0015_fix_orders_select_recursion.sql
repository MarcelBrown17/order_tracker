-- Fix infinite recursion: orders_select must not query public.orders
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
