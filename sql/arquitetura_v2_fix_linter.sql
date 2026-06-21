-- Essa migration vai alterar as funções _já existentes_ para SECURITY INVOKER e SET search_path = public

ALTER FUNCTION public.get_jbp_data(text[], text[], text[], text[], text[], text[], text[], text[], text, text[], text[]) SET search_path = public;
ALTER FUNCTION public.get_jbp_data(text[], text[], text[], text[], text[], text[], text[], text[], text, text[], text[]) SECURITY INVOKER;

ALTER FUNCTION public.get_jbp_data(text[], text[], text[], text[], text[], text[], text[], text[], text, text, text[], text[]) SET search_path = public;
ALTER FUNCTION public.get_jbp_data(text[], text[], text[], text[], text[], text[], text[], text[], text, text, text[], text[]) SECURITY INVOKER;

ALTER FUNCTION public._run_full_system() SET search_path = public;
ALTER FUNCTION public.f_unaccent(text) SET search_path = public;

ALTER FUNCTION public.sync_sheets_manually() SET search_path = public;
ALTER FUNCTION public.upsert_dim_vendedores(jsonb) SET search_path = public;
ALTER FUNCTION public.execute_sync_sheets() SET search_path = public;

ALTER FUNCTION public.get_boxes_dashboard_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_branch_comparison_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_city_view_data(text[], text[], text[], text[], text[], text, text, text[], text[], integer, integer, integer, integer, text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_comparison_view_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_data_version() SECURITY INVOKER;
ALTER FUNCTION public.get_estrelas_kpis_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_frequency_table_data(text, text, text[], text[], text[], text[], text[], text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_innovations_data(text[], text[], text[], text[], text[], text[], text, text, text) SECURITY INVOKER;
ALTER FUNCTION public.get_jbp_inovacoes_details(integer, integer, text, text) SECURITY INVOKER;
ALTER FUNCTION public.get_loja_perfeita_data(text[], text[], text[], text[], text[], text, integer, integer, text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_main_dashboard_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.get_mix_salty_foods_data(text, text, text[], text[], text[], text[], text[], text[], text[], text[], text[]) SECURITY INVOKER;

ALTER FUNCTION public.search_clients(text) SECURITY INVOKER;

ALTER FUNCTION public.search_loja_perfeita_clients(text, text[], text[], text[], text[], text[]) SECURITY INVOKER;
ALTER FUNCTION public.search_loja_perfeita_clients(text, text[], text[], text[], text[], text[], text[]) SECURITY INVOKER;
