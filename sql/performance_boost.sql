-- ==============================================================================
-- PERFORMANCE BOOST AND SECURITY FIXES
-- This script applies BRIN indexing, Parallelism, and fixes Supabase Linter Warnings
-- sem duplicar o tamanho das tabelas principais.
-- ==============================================================================

-- 1. DROP DUPLICATE INDEXES TO SAVE SPACE
DROP INDEX IF EXISTS public.idx_dim_produtos_categoria_produto;

-- 2. APPLY BRIN INDEXES FOR TIME-SERIES DATA (Saves disk space and speeds up date filtering)
-- BRIN indexes group rows by pages. Because sales data is typically inserted chronologically,
-- BRIN is incredibly efficient for filtering by dtped, shrinking index sizes by 99%.
CREATE INDEX IF NOT EXISTS idx_data_detailed_dtped_brin ON public.data_detailed USING brin (dtped) WITH (pages_per_range = 128);
CREATE INDEX IF NOT EXISTS idx_data_history_dtped_brin ON public.data_history USING brin (dtped) WITH (pages_per_range = 128);

-- Liberando muito espaço: removendo os B-Tree antigos pesados nas datas.
DROP INDEX IF EXISTS public.idx_data_detailed_dtped;
DROP INDEX IF EXISTS public.idx_data_history_dtped;

-- 3. ENABLE AUTOMATIC PARALLELISM
-- Permite ao PostgreSQL dividir cargas pesadas de leitura e agrupamento em múltiplos núcleos.
ALTER DATABASE postgres SET max_parallel_workers_per_gather = 2;
ALTER DATABASE postgres SET max_parallel_workers = 4;
ALTER DATABASE postgres SET parallel_setup_cost = 1000;
ALTER DATABASE postgres SET parallel_tuple_cost = 0.1;

-- 4. FIX RLS INITPLAN WARNINGS (Performance issue with RLS policies)
-- The Supabase linter complains that auth.<function>() evaluates per row.
-- Wrapping them in (SELECT auth.role()) forces it to evaluate once per query.

-- Fix for meta_estrelas
DROP POLICY IF EXISTS "Allow authenticated full access meta_estrelas" ON public.meta_estrelas;
CREATE POLICY "Allow authenticated full access meta_estrelas" ON public.meta_estrelas
    FOR ALL
    TO authenticated
    USING ( (SELECT auth.role()) = 'authenticated' )
    WITH CHECK ( (SELECT auth.role()) = 'authenticated' );

-- Fix for supervisors_routes
DROP POLICY IF EXISTS "Enable update/insert for authenticated users" ON public.supervisors_routes;
CREATE POLICY "Enable update/insert for authenticated users" ON public.supervisors_routes
    FOR ALL
    TO authenticated
    USING ( (SELECT auth.role()) = 'authenticated' )
    WITH CHECK ( (SELECT auth.role()) = 'authenticated' );

-- Fix for n8n_auth_colaboradores
DROP POLICY IF EXISTS "Enable update/insert for authenticated users" ON public.n8n_auth_colaboradores;
CREATE POLICY "Enable update/insert for authenticated users" ON public.n8n_auth_colaboradores
    FOR ALL
    TO authenticated
    USING ( (SELECT auth.role()) = 'authenticated' )
    WITH CHECK ( (SELECT auth.role()) = 'authenticated' );


-- 5. MATERIALIZED VIEW SECURITY
-- Linter Warning: Materialized view `public.mv_frequencia_cliente` is selectable by anon or authenticated roles
-- Ensure no public direct access.
REVOKE SELECT ON public.mv_frequencia_cliente FROM anon;
REVOKE SELECT ON public.mv_frequencia_cliente FROM authenticated;

-- 6. SECURITY DEFINER / SEARCH PATH WARNINGS
-- By executing this block, we dynamically alter all functions in the public schema
-- to explicitly set their search_path to public. This instantly resolves ALL
-- "Function Search Path Mutable" warnings on Supabase.
DO $$
DECLARE
    func record;
BEGIN
    FOR func IN
        SELECT p.oid::regprocedure::text AS signature
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
    LOOP
        EXECUTE 'ALTER FUNCTION ' || func.signature || ' SET search_path = public';
    END LOOP;
END $$;


-- ==============================================================================
-- 7. GLOBAL KPIs MATERIALIZED VIEW
-- ==============================================================================
-- This materialized view pre-calculates the global (unfiltered) KPIs.
-- We must refresh this concurrently after data updates.
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_dashboard_globals AS
SELECT
    ano,
    SUM(CASE WHEN tipovenda IN ('5', '11') THEN bonificacao::numeric ELSE vlvenda::numeric END) as faturamento_total,
    SUM(peso) as peso_total,
    SUM(COALESCE(caixas, 0)) as caixas_total,
    COUNT(DISTINCT CASE WHEN tipovenda NOT IN ('5', '11') AND pre_positivacao_val >= 1 THEN codcli END) as clientes_atendidos
FROM public.data_summary
GROUP BY ano;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_dashboard_globals_ano ON public.mv_dashboard_globals (ano);

-- Function to refresh the view safely
CREATE OR REPLACE FUNCTION public.refresh_mv_dashboard_globals()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Concurrent refresh is fast and doesn't block readers
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_dashboard_globals;
END;
$$;
