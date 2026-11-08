-- Public checkout: pay now or at end of month.
-- End of month is stored as date_paid = last day of the order month (same rule as the admin "Pay end of month" toggle).

drop function if exists public.submit_biscuit_request(text, text, text, text, jsonb);

create or replace function public.submit_biscuit_request(
  p_customer_name text,
  p_company text default null,
  p_contact text default null,
  p_notes text default null,
  p_items jsonb default '[]'::jsonb,
  p_pay_eom boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  grp uuid := gen_random_uuid();
  item jsonb;
  pid uuid;
  qty integer;
  product_row public.products%rowtype;
  note_text text;
  name_clean text;
  today date := (now() at time zone 'Africa/Johannesburg')::date;
  paid_on date;
begin
  name_clean := trim(coalesce(p_customer_name, ''));
  if name_clean = '' then
    raise exception 'Customer name is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one item';
  end if;

  paid_on := case
    when coalesce(p_pay_eom, false)
      then (date_trunc('month', today) + interval '1 month - 1 day')::date
    else today
  end;

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
      today,
      paid_on,
      note_text,
      null,
      grp,
      'admin'
    );
  end loop;

  return grp;
end;
$$;

revoke all on function public.submit_biscuit_request(text, text, text, text, jsonb, boolean) from public;
grant execute on function public.submit_biscuit_request(text, text, text, text, jsonb, boolean) to anon, authenticated;
