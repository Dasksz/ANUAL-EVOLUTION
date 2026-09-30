-- Harden functions used by the WhatsApp agent and shared authorization helpers.
-- This script is idempotent; it was applied to the EVOLUÇÃO ANUAL project as
-- the Supabase migration harden_agent_database_functions.

ALTER FUNCTION public.sp_clientes_sem_venda_rca(text, text)
  SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.handle_new_user()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.is_admin()
  FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION public.is_approved()
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.is_admin()
  TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.is_approved()
  TO authenticated, service_role;

ALTER FUNCTION public.handle_new_user()
  SET search_path = pg_catalog;

ALTER FUNCTION public.is_admin()
  SET search_path = pg_catalog;

ALTER FUNCTION public.is_approved()
  SET search_path = pg_catalog;
