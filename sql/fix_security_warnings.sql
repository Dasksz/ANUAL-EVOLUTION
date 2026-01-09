
-- ==============================================================================
-- SECURITY FIX: IMMUTABLE SEARCH PATHS
-- Fixes 'Function Search Path Mutable' warnings by explicit setting search_path
-- ==============================================================================

-- 1. Dashboard Data & Filters
ALTER FUNCTION public.get_main_dashboard_data(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public, extensions, temp;
ALTER FUNCTION public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public, extensions, temp;
ALTER FUNCTION public.get_city_view_data(text[], text[], text[], text[], text[], text, text, text[], int, int, int, int) SET search_path = public, extensions, temp;

-- 2. Maintenance & Refresh Functions
ALTER FUNCTION public.clear_all_data() SET search_path = public, extensions, temp;
ALTER FUNCTION public.refresh_cache_filters() SET search_path = public, extensions, temp;
ALTER FUNCTION public.refresh_cache_summary() SET search_path = public, extensions, temp;
ALTER FUNCTION public.refresh_dashboard_cache() SET search_path = public, extensions, temp;
ALTER FUNCTION public.truncate_table(text) SET search_path = public, extensions, temp;
ALTER FUNCTION public.optimize_database() SET search_path = public, extensions, temp;

-- 3. Utility & Logic Functions
ALTER FUNCTION public.get_data_version() SET search_path = public, extensions, temp;
ALTER FUNCTION public.toggle_holiday(date) SET search_path = public, extensions, temp;
ALTER FUNCTION public.calc_working_days(date, date) SET search_path = public, extensions, temp;

-- 4. Security Helper Functions
ALTER FUNCTION public.is_admin() SET search_path = public, extensions, temp;
ALTER FUNCTION public.is_approved() SET search_path = public, extensions, temp;

-- Note: 'auth_leaked_password_protection' is a global Supabase config, not a SQL function.
-- To fix it, you need to enable "Enable Leaked Password Protection" in Supabase Dashboard > Authentication > Security.
