-- The dashboard only needs chart targets. Detailed ownership diagnostics remain in the goals page.
CREATE OR REPLACE FUNCTION public.get_dashboard_metas(p_filters jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET statement_timeout='55s' AS $$
BEGIN
 PERFORM private.evolution_assert_approved();
 RETURN private.evolution_dashboard_metas_original(p_filters);
END $$;
REVOKE ALL ON FUNCTION public.get_dashboard_metas(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_metas(jsonb) TO authenticated;

