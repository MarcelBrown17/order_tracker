-- Pearl joins as a partner with no commission. Her login is created in Supabase Auth
-- and linked to this row by email on first sign in.
insert into public.users (name, email, is_admin)
select 'Pearl', 'pearl@gmail.com', false
where not exists (
  select 1 from public.users where lower(email) = 'pearl@gmail.com'
);

-- Email Marcel when a partner adds a new order. One request per insert statement,
-- so a multi-product order sends one email. Lines added to an existing order are ignored.

create or replace function public.partner_order_alert(p_secret text, p_group_ids uuid[])
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
    select jsonb_agg(to_jsonb(r) order by r.order_group_id, r.product_name)
    from (
      select
        o.id,
        o.order_group_id,
        u.name as partner_name,
        o.customer_name,
        o.customer_contact,
        o.order_date,
        o.date_paid,
        p.name as product_name,
        o.quantity,
        o.unit_sell_price,
        (
          o.date_paid is not null
          and o.date_paid = (date_trunc('month', o.date_paid) + interval '1 month - 1 day')::date
        ) as pay_eom
      from public.orders o
      join public.products p on p.id = o.product_id
      join public.users u on u.id = o.created_by
      where o.order_group_id = any(p_group_ids)
    ) r
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.partner_order_alert(text, uuid[]) from public, anon, authenticated;
grant execute on function public.partner_order_alert(text, uuid[]) to service_role;

create or replace function private.notify_partner_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  group_ids uuid[];
begin
  select array_agg(distinct n.order_group_id) into group_ids
  from new_rows n
  join public.users u on u.id = n.created_by
  where not coalesce(u.is_admin, false)
    and not exists (
      select 1
      from public.orders o
      where o.order_group_id = n.order_group_id
        and o.id not in (select id from new_rows)
    );

  if group_ids is null then
    return null;
  end if;

  perform net.http_post(
    url := 'https://gfsaxcnodjcvxpegooat.supabase.co/functions/v1/partner-order-alert',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-report-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'order_report_secret')
    ),
    body := jsonb_build_object('group_ids', group_ids),
    timeout_milliseconds := 30000
  );

  return null;
end;
$$;

drop trigger if exists trg_orders_notify_partner_order on public.orders;
create trigger trg_orders_notify_partner_order
after insert on public.orders
referencing new table as new_rows
for each statement
execute function private.notify_partner_order();
