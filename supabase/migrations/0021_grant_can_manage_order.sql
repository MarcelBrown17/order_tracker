-- RLS policies call private.can_manage_order; authenticated must be able to execute it.
revoke all on function private.can_manage_order(uuid) from public;
grant execute on function private.can_manage_order(uuid) to authenticated;
