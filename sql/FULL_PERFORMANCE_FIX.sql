
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

-- Function: Get Filters (Optimized - Split Queries for Better Index Usage)
CREATE OR REPLACE FUNCTION get_dashboard_filters(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_supervisors text[];
    v_vendedores text[];
    v_fornecedores json;
    v_cidades text[];
    v_filiais text[];
    v_anos int[];
    v_tipos_venda text[];

    v_filter_year int;
    v_filter_month int;
BEGIN
    SET LOCAL statement_timeout = '120s';

    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
    ELSE
        SELECT COALESCE(GREATEST(
            (SELECT MAX(EXTRACT(YEAR FROM dtped))::int FROM public.data_detailed),
            (SELECT MAX(EXTRACT(YEAR FROM dtped))::int FROM public.data_history)
        ), EXTRACT(YEAR FROM CURRENT_DATE)::int)
        INTO v_filter_year;

        -- Default to null if not explicit, but use date range implicitly in cache if needed.
        -- Actually, cache_filters has 'ano', so we use v_filter_year.
        -- However, if user wants ALL years, we should keep v_filter_year NULL if p_ano was 'todos'.
        -- Re-evaluating: The logic in RPC was to use NULL for 'todos'.
        -- If p_ano IS 'todos', v_filter_year remains NULL.
        IF p_ano = 'todos' THEN v_filter_year := NULL; END IF;
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_filter_month := p_mes::int + 1;
    END IF;

    -- 1. Supervisors
    SELECT ARRAY(SELECT DISTINCT superv FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY superv
    ) INTO v_supervisors;

    -- 2. Vendedores
    SELECT ARRAY(SELECT DISTINCT nome FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY nome
    ) INTO v_vendedores;

    -- 3. Cidades
    SELECT ARRAY(SELECT DISTINCT cidade FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY cidade
    ) INTO v_cidades;

    -- 4. Filiais
    SELECT ARRAY(SELECT DISTINCT filial FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY filial
    ) INTO v_filiais;

    -- 5. Tipos de Venda
    SELECT ARRAY(SELECT DISTINCT tipovenda FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND tipovenda IS NOT NULL AND tipovenda != '' AND tipovenda != 'null'
        ORDER BY tipovenda
    ) INTO v_tipos_venda;

    -- 6. Fornecedores
    SELECT json_agg(json_build_object('cod', codfor, 'name',
        CASE
            WHEN codfor = '707' THEN 'Extrusados'
            WHEN codfor = '708' THEN 'Ñ Extrusados'
            WHEN codfor = '752' THEN 'Torcida'
            WHEN codfor = '1119' THEN 'Foods'
            ELSE fornecedor
        END
    ) ORDER BY
        CASE
            WHEN codfor = '707' THEN 'Extrusados'
            WHEN codfor = '708' THEN 'Ñ Extrusados'
            WHEN codfor = '752' THEN 'Torcida'
            WHEN codfor = '1119' THEN 'Foods'
            ELSE fornecedor
        END
    ) INTO v_fornecedores
    FROM (
        SELECT DISTINCT codfor, fornecedor
        FROM public.cache_filters
        WHERE
            (v_filter_year IS NULL OR ano = v_filter_year)
            AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
            AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
            AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
            AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
            AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
            AND (v_filter_month IS NULL OR mes = v_filter_month)
            AND codfor IS NOT NULL
    ) t;

    -- 7. Anos
    SELECT ARRAY(SELECT DISTINCT ano FROM public.cache_filters WHERE
        (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY ano DESC
    ) INTO v_anos;

    RETURN json_build_object(
        'supervisors', COALESCE(v_supervisors, '{}'),
        'vendedores', COALESCE(v_vendedores, '{}'),
        'fornecedores', COALESCE(v_fornecedores, '[]'::json),
        'cidades', COALESCE(v_cidades, '{}'),
        'filiais', COALESCE(v_filiais, '{}'),
        'anos', COALESCE(v_anos, '{}'),
        'tipos_venda', COALESCE(v_tipos_venda, '{}')
    );
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
