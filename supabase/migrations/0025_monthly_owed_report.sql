-- Monthly owed report: on the 23rd, cron calls the monthly-owed-report edge function,
-- which emails a PDF of unpaid end-of-month orders plus other pending orders.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  encode(extensions.gen_random_bytes(32), 'hex'),
  'order_report_secret',
  'Shared secret between cron and the monthly-owed-report edge function'
)
where not exists (
  select 1 from vault.secrets where name = 'order_report_secret'
);

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
        o.company,
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

-- 06:00 UTC = 08:00 South Africa
select cron.schedule(
  'monthly-owed-report',
  '0 6 23 * *',
  $$
  select net.http_post(
    url := 'https://gfsaxcnodjcvxpegooat.supabase.co/functions/v1/monthly-owed-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-report-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'order_report_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
