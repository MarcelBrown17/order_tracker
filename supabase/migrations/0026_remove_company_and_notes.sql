-- Drop company and notes from orders; update public request + report RPCs.

drop function if exists public.submit_biscuit_request(text, text, text, text, jsonb);
drop function if exists public.submit_biscuit_request(text, text, text, text, jsonb, boolean);

create or replace function public.submit_biscuit_request(
  p_customer_name text,
  p_contact text default null,
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
      customer_contact,
      product_id,
      quantity,
      unit_cost,
      unit_sell_price,
      is_bulk,
      status,
      order_date,
      date_paid,
      created_by,
      order_group_id,
      order_type
    )
    values (
      name_clean,
      nullif(trim(coalesce(p_contact, '')), ''),
      product_row.id,
      qty,
      product_row.cost_price,
      product_row.sell_price,
      false,
      'pending',
      today,
      paid_on,
      null,
      grp,
      'admin'
    );
  end loop;

  return grp;
end;
$$;

revoke all on function public.submit_biscuit_request(text, text, jsonb, boolean) from public;
grant execute on function public.submit_biscuit_request(text, text, jsonb, boolean) to anon, authenticated;

create or replace function public.owed_report(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  expected text;
begin
  select decrypted_secret into expected
  from vault.decrypted_secrets
  where name = 'order_report_secret';

  if expected is null or p_secret is distinct from expected then
    raise exception 'Not allowed';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(r) order by r.customer_name, r.order_date, r.product_name)
    from (
      select
        o.order_group_id,
        o.customer_name,
        o.order_date,
        o.date_paid,
        o.order_type,
        p.name as product_name,
        o.quantity,
        o.unit_sell_price,
        (
          o.date_paid is not null
          and o.date_paid = (date_trunc('month', o.date_paid) + interval '1 month - 1 day')::date
        ) as pay_eom
      from public.orders o
      join public.products p on p.id = o.product_id
      where o.status = 'pending'
    ) r
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.owed_report(text) from public, anon, authenticated;
grant execute on function public.owed_report(text) to service_role;

drop view if exists public.order_summary;

alter table public.orders
  drop column if exists company,
  drop column if exists notes;

create view public.order_summary
with (security_invoker = true)
as
select
  o.*,
  p.name as product_name,
  (o.unit_sell_price - o.unit_cost) * o.quantity as profit_total
from public.orders o
join public.products p on p.id = o.product_id;

grant select on public.order_summary to authenticated;
