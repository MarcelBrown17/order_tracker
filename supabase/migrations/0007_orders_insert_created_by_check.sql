-- Partners may only attribute orders to themselves on insert

drop policy if exists "orders_insert" on public.orders;

create policy "orders_insert"
  on public.orders for insert to authenticated
  with check (
    private.is_admin()
    or (
      private.partner_id() is not null
      and (created_by is null or created_by = private.partner_id())
    )
  );
