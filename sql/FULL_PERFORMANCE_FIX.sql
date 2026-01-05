
-- ==============================================================================
-- FULL PERFORMANCE FIX & CLEANUP SCRIPT
-- RUN THIS SCRIPT IN SUPABASE SQL EDITOR TO FIX TIMEOUTS AND WARNINGS
-- ==============================================================================

-- 1. DATABASE OPTIMIZATION: Indexes for Sales Data (Fixes Dashboard Timeouts)
-- ------------------------------------------------------------------------------

-- Detailed Table Index (Covers main dashboard queries AND kpi_base_clients)
DROP INDEX IF EXISTS idx_detailed_dtped_composite;
CREATE INDEX idx_detailed_dtped_composite
ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

-- History Table Index (Covers main dashboard queries AND kpi_base_clients)
DROP INDEX IF EXISTS idx_history_dtped_composite;
CREATE INDEX idx_history_dtped_composite
ON public.data_history (dtped, filial, cidade, superv, nome, codfor)
INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

-- 2. CACHE OPTIMIZATION: Indexes and Logic for Filters (Fixes Filter Timeouts)
-- ------------------------------------------------------------------------------

-- Drop old single-column indexes in favor of composites
DROP INDEX IF EXISTS idx_cache_filters_composite;
DROP INDEX IF EXISTS idx_cache_filters_superv_composite;
DROP INDEX IF EXISTS idx_cache_filters_nome_composite;
DROP INDEX IF EXISTS idx_cache_filters_cidade_composite;

-- Main composite index
CREATE INDEX idx_cache_filters_composite
ON public.cache_filters (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);

-- Specialized lookup indexes
CREATE INDEX IF NOT EXISTS idx_cache_filters_superv_lookup ON public.cache_filters (filial, cidade, ano, superv);
CREATE INDEX IF NOT EXISTS idx_cache_filters_nome_lookup ON public.cache_filters (filial, cidade, superv, ano, nome);
CREATE INDEX IF NOT EXISTS idx_cache_filters_cidade_lookup ON public.cache_filters (filial, ano, cidade);

-- Optimized Refresh Function
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes)
    SELECT DISTINCT
        filial, cidade, superv, nome, codfor, fornecedor, tipovenda, yr, mth
    FROM (
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_detailed
        GROUP BY 1,2,3,4,5,6,7,8,9
        UNION ALL
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_history
        GROUP BY 1,2,3,4,5,6,7,8,9
    ) t;
END;
$$;

-- 3. SUPABASE WARNINGS: Fix Duplicates and Security
-- ------------------------------------------------------------------------------

-- Drop Duplicate Indexes
DROP INDEX IF EXISTS public.idx_cache_filters_fornecedor_col;
DROP INDEX IF EXISTS public.idx_detailed_cidade_btree;
DROP INDEX IF EXISTS public.idx_detailed_filial_btree;
DROP INDEX IF EXISTS public.idx_detailed_nome_btree;
DROP INDEX IF EXISTS public.idx_detailed_superv_btree;
DROP INDEX IF EXISTS public.idx_history_cidade_btree;
DROP INDEX IF EXISTS public.idx_history_filial_btree;
DROP INDEX IF EXISTS public.idx_history_nome_btree;
DROP INDEX IF EXISTS public.idx_history_superv_btree;

-- Fix RLS Policies (Profiles)
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT
WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE
USING ((select auth.uid()) = id)
WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Profiles Visibility" ON public.profiles;
CREATE POLICY "Profiles Visibility" ON public.profiles FOR SELECT
USING ((select auth.uid()) = id OR public.is_admin());

-- Remove Insecure Default Policies
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);
        IF t = 'profiles' THEN
             EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
        END IF;
    END LOOP;
END $$;

-- 4. APPLY CACHE REFRESH (Run this last)
-- ------------------------------------------------------------------------------
SELECT refresh_dashboard_cache();
