-- Fix: RLS policies call private.is_admin() / private.partner_id()
-- but execute was only granted on the public wrappers.

grant usage on schema private to authenticated;

grant execute on function private.is_admin() to authenticated;
grant execute on function private.partner_id() to authenticated;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.current_partner_id() to authenticated;

-- Ensure Marcel stays linked for admin access
update public.users
set
  is_admin = true,
  email = 'marcelbrown413@gmail.com'
where name = 'Marcel';
