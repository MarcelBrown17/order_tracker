-- Partners may update status on orders they created (status only via RPC)

create or replace function public.set_order_status(
  p_order_id uuid,
  p_status text
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.orders;
  me uuid := private.partner_id();
begin
  if p_status is null or p_status not in ('pending', 'paid', 'cancelled') then
    raise exception 'Invalid status';
  end if;

  if me is null then
    raise exception 'Not linked to a partner';
  end if;

  if not (
    private.is_admin()
    or exists (
      select 1
      from public.orders o
      where o.id = p_order_id
        and o.created_by = me
    )
  ) then
    raise exception 'Not allowed to update this order';
  end if;

  update public.orders
  set status = p_status
  where id = p_order_id
  returning * into result;

  if result.id is null then
    raise exception 'Order not found';
  end if;

  return result;
end;
$$;

revoke all on function public.set_order_status(uuid, text) from public;
grant execute on function public.set_order_status(uuid, text) to authenticated;
