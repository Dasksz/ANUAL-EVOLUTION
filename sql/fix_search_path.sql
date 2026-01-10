-- Fix function_search_path_mutable warnings by setting search_path to public

ALTER FUNCTION public.is_admin() SET search_path = public;
ALTER FUNCTION public.is_approved() SET search_path = public;
ALTER FUNCTION public.clear_all_data() SET search_path = public;
ALTER FUNCTION public.truncate_table(text) SET search_path = public;
ALTER FUNCTION public.refresh_cache_filters() SET search_path = public;
ALTER FUNCTION public.refresh_cache_summary() SET search_path = public;
ALTER FUNCTION public.refresh_dashboard_cache() SET search_path = public;
ALTER FUNCTION public.optimize_database() SET search_path = public;
ALTER FUNCTION public.toggle_holiday(date) SET search_path = public;
ALTER FUNCTION public.calc_working_days(date, date) SET search_path = public;
ALTER FUNCTION public.get_data_version() SET search_path = public;
ALTER FUNCTION public.get_main_dashboard_data(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public;
ALTER FUNCTION public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public;
ALTER FUNCTION public.get_city_view_data(text[], text[], text[], text[], text[], text, text, text[], int, int, int, int) SET search_path = public;
