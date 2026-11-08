alter table public.products
  add column if not exists category text not null default 'biscuits';

alter table public.products
  drop constraint if exists products_category_check;

alter table public.products
  add constraint products_category_check
  check (category in ('biscuits', 'other'));

update public.products
set category = 'other'
where name in ('Pies (bag of 3)', 'Samoosas (bag of 3)');

drop function if exists public.list_public_products();

create function public.list_public_products()
returns table (
  id uuid,
  name text,
  sell_price numeric,
  category text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.name, p.sell_price, p.category
  from public.products p
  where p.active = true
  order by p.category, p.name;
$$;

revoke all on function public.list_public_products() from public;
grant execute on function public.list_public_products() to anon, authenticated;
