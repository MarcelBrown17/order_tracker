-- Public biscuit requests: list active products + submit as pending admin orders

create or replace function public.list_public_products()
returns table (
  id uuid,
  name text,
  sell_price numeric
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.name, p.sell_price
  from public.products p
  where p.active = true
  order by p.name;
$$;

revoke all on function public.list_public_products() from public;
grant execute on function public.list_public_products() to anon, authenticated;

create or replace function public.submit_biscuit_request(
  p_customer_name text,
  p_company text default null,
  p_contact text default null,
  p_notes text default null,
  p_items jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  grp uuid := gen_random_uuid();
  first_order_id uuid;
  item jsonb;
  pid uuid;
  qty integer;
  product_row public.products%rowtype;
  note_text text;
  name_clean text;
begin
  name_clean := trim(coalesce(p_customer_name, ''));
  if name_clean = '' then
    raise exception 'Customer name is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one biscuit';
  end if;

  note_text := nullif(trim(coalesce(p_notes, '')), '');
  if note_text is null then
    note_text := 'Online request';
  else
    note_text := 'Online request · ' || note_text;
  end if;

  for item in select * from jsonb_array_elements(p_items)
  loop
    begin
      pid := (item->>'product_id')::uuid;
    exception when others then
      raise exception 'Invalid product';
    end;

    qty := greatest(1, coalesce((item->>'quantity')::integer, 0));

    select * into product_row
    from public.products p
    where p.id = pid
      and p.active = true;

    if not found then
      raise exception 'Product is not available';
    end if;

    insert into public.orders (
      customer_name,
      company,
      customer_contact,
      product_id,
      quantity,
      unit_cost,
      unit_sell_price,
      is_bulk,
      status,
      order_date,
      date_paid,
      notes,
      created_by,
      order_group_id,
      order_type
    )
    values (
      name_clean,
      nullif(trim(coalesce(p_company, '')), ''),
      nullif(trim(coalesce(p_contact, '')), ''),
      product_row.id,
      qty,
      product_row.cost_price,
      product_row.sell_price,
      false,
      'pending',
      current_date,
      current_date,
      note_text,
      null,
      grp,
      'admin'
    )
    returning id into first_order_id;
  end loop;

  return grp;
end;
$$;

revoke all on function public.submit_biscuit_request(text, text, text, text, jsonb) from public;
grant execute on function public.submit_biscuit_request(text, text, text, text, jsonb) to anon, authenticated;
