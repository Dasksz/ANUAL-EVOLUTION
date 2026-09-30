-- No business rows or credentials are deleted. Service integrations retain access.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.evolution_assert_admin()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp
AS $guard$
BEGIN
  IF COALESCE(public.is_admin(), false) OR
     (session_user IN ('postgres', 'supabase_admin')
      AND current_setting('role', true) IN ('none', 'postgres', 'supabase_admin')) THEN
    RETURN;
  END IF;
  RAISE EXCEPTION 'Acesso administrativo necessário.' USING ERRCODE = '42501';
END;
$guard$;
CREATE OR REPLACE FUNCTION private.evolution_assert_approved()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp
AS $guard$
BEGIN
  IF COALESCE(public.is_approved(), false) OR
     (session_user IN ('postgres', 'supabase_admin')
      AND current_setting('role', true) IN ('none', 'postgres', 'supabase_admin')) THEN
    RETURN;
  END IF;
  RAISE EXCEPTION 'Acesso aprovado necessário.' USING ERRCODE = '42501';
END;
$guard$;
REVOKE ALL ON FUNCTION private.evolution_assert_admin(), private.evolution_assert_approved() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.evolution_assert_admin(), private.evolution_assert_approved() TO authenticated, service_role;

-- Trigger keeps the existing admin management flow, but blocks self-promotion.
CREATE OR REPLACE FUNCTION private.protect_profile_authorization()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = public, pg_temp
AS $guard$
BEGIN
  IF current_user IN ('postgres','supabase_admin','supabase_auth_admin','service_role')
     OR COALESCE(public.is_admin(), false) THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.role IS DISTINCT FROM 'user' OR NEW.status IS DISTINCT FROM 'pendente' THEN
      RAISE EXCEPTION 'Somente administradores podem definir permissões.' USING ERRCODE='42501';
    END IF;
  ELSIF NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status
        OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Somente administradores podem alterar permissões.' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION private.protect_profile_authorization() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS protect_profile_authorization ON public.profiles;
CREATE TRIGGER protect_profile_authorization BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION private.protect_profile_authorization();

-- Secrets are now consumed by the presentation-analysis server function only.
DROP POLICY IF EXISTS "Allow read access to api_ia" ON public.api_ia;
REVOKE ALL ON TABLE public.api_ia FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.api_ia TO service_role;

-- Replace permissive policies while keeping approved users' legitimate workflows.
DO $policies$
DECLARE r record; t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['metas_sv','meta_estrelas','supervisors_routes','v_cliente_filial','n8n_auth_colaboradores'] LOOP
    FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
      EXECUTE format('DROP POLICY %I ON public.%I',r.policyname,t);
    END LOOP;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon',t);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role',t);
    IF t='n8n_auth_colaboradores' THEN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM authenticated',t);
    ELSE
      EXECUTE format('CREATE POLICY approved_read ON public.%I FOR SELECT TO authenticated USING ((SELECT public.is_approved()))',t);
      IF t IN ('metas_sv','supervisors_routes') THEN
        EXECUTE format('CREATE POLICY approved_write ON public.%I FOR ALL TO authenticated USING ((SELECT public.is_approved())) WITH CHECK ((SELECT public.is_approved()))',t);
      ELSE
        EXECUTE format('CREATE POLICY admin_write ON public.%I FOR ALL TO authenticated USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()))',t);
      END IF;
    END IF;
  END LOOP;
END;
$policies$;

ALTER VIEW public.n8n_vw_validar_identidade SET (security_invoker=true);
ALTER VIEW public.n8n_agent_view_v2 SET (security_invoker=true);
REVOKE ALL ON public.n8n_vw_validar_identidade, public.n8n_agent_view_v2,
  public.n8n_agent_clientes_sem_venda_view FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.n8n_vw_validar_identidade, public.n8n_agent_view_v2,
  public.n8n_agent_clientes_sem_venda_view TO service_role;

-- Keep SQL definitions private while applying guards to existing entry points.
DO $functions$
DECLARE r record; definition text; guard_name text;
BEGIN
  FOR r IN
    SELECT p.oid,p.proname,p.oid::regprocedure AS signature,l.lanname,p.prosecdef,p.prosrc
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    JOIN pg_language l ON l.oid=p.prolang
    WHERE n.nspname='public' AND p.prokind='f' AND l.lanname IN ('sql','plpgsql')
  LOOP
    guard_name := NULL;
    IF r.proname = ANY(ARRAY[
      'admin_get_cities','admin_update_city_populations','append_sync_chunk','append_to_chunk_v2',
      'begin_sync_chunk','commit_sync_chunk','clear_all_data','clear_summary_month','delete_by_hashes',
      'execute_sync_sheets','get_table_hashes','optimize_database','refresh_cache_filters',
      'refresh_cache_summary','refresh_cache_summary_detailed','refresh_cache_summary_history',
      'refresh_dashboard_cache','refresh_data_financials','refresh_mv_dashboard_globals',
      'refresh_summary_chunk','refresh_summary_month','refresh_summary_year','sync_chunk_v2',
      'sync_sales_chunk','sync_sheets_manually','toggle_holiday','truncate_table',
      'update_products_stock','upsert_dim_vendedores'
    ]) THEN
      guard_name := 'evolution_assert_admin';
    ELSIF r.proname LIKE 'get\_%' ESCAPE '\' OR r.proname IN
      ('search_clients','search_loja_perfeita_clients','save_meta_sv','save_meta_crescimento','upsert_metas') THEN
      guard_name := 'evolution_assert_approved';
    END IF;
    IF r.proname LIKE 'sp\_%' ESCAPE '\' THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',r.signature);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',r.signature);
    ELSIF guard_name IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon',r.signature);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role',r.signature);
      IF r.lanname='plpgsql' AND strpos(r.prosrc, 'private.' || guard_name || '()')=0 THEN
        definition := pg_get_functiondef(r.oid);
        definition := regexp_replace(definition, '\mBEGIN\M',
          E'BEGIN\n    PERFORM private.' || guard_name || '();', 'i');
        EXECUTE definition;
      END IF;
      EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp',r.signature);
    END IF;
  END LOOP;
END;
$functions$;
NOTIFY pgrst, 'reload schema';
