
-- ==============================================================================
-- FIX RESIDUAL SECURITY WARNINGS
-- Targets specific functions and overloads reported by Supabase Linter
-- ==============================================================================

-- 1. Dashboard Main Data
ALTER FUNCTION public.get_main_dashboard_data(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public, extensions, temp;

-- 2. Filters (Handling potential overloads/duplicates)
ALTER FUNCTION public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[]) SET search_path = public, extensions, temp;

-- 3. City View Data (Targeting all overloads via Dynamic SQL)
-- The user reported multiple warnings for this function, suggesting different parameter signatures exist.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure as signature
        FROM pg_proc
        WHERE proname = 'get_city_view_data' AND pronamespace = 'public'::regnamespace
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions, temp', r.signature);
    END LOOP;
END $$;
