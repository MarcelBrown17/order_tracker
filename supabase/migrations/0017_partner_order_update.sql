-- Allow linked partners to UPDATE (and DELETE line rows) on orders they can manage,
-- matching public.set_order_status permission rules.

create or replace function private.can_manage_order(p_order_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := private.partner_id();
  me_name text;
  grp uuid;
  typ text;
begin
  if me is null then
    return false;
  end if;

  if private.is_admin() then
    return true;
  end if;

  select lower(u.name) into me_name
  from public.users u
  where u.id = me;

  select o.order_group_id, o.order_type into grp, typ
  from public.orders o
  where o.id = p_order_id;

  if grp is null then
    return false;
  end if;

  return exists (
    select 1
    from public.orders o
    where o.order_group_id = grp
      and o.created_by = me
  )
  or (typ = 'delton' and me_name = 'delton')
  or (typ = 'richard' and me_name = 'richard');
end;
$$;

revoke all on function private.can_manage_order(uuid) from public;

drop policy if exists "orders_update_admin" on public.orders;
drop policy if exists "orders_update" on public.orders;
drop policy if exists "orders_delete_admin" on public.orders;
drop policy if exists "orders_delete" on public.orders;

create policy "orders_update"
  on public.orders for update to authenticated
  using (private.can_manage_order(id))
  with check (private.can_manage_order(id));

create policy "orders_delete"
  on public.orders for delete to authenticated
  using (private.can_manage_order(id));
