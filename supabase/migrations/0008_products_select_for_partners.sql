-- Partners need to read products for the New Order dropdown

drop policy if exists "products_select_admin" on public.products;
drop policy if exists "products_select" on public.products;

create policy "products_select"
  on public.products for select to authenticated
  using (private.is_admin() or private.partner_id() is not null);
