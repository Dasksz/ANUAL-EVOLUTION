
-- ==============================================================================
-- FIX CACHE PERFORMANCE & REFRESH LOGIC
-- ==============================================================================

-- 1. Optimize Cache Table Indexes
-- The previous indexes were single-column. We need composite indexes to support the dependent filtering queries.
-- For example, filtering Supervisors by (Filial + Cidade + Ano).

DROP INDEX IF EXISTS idx_cache_filters_composite;
DROP INDEX IF EXISTS idx_cache_filters_superv_composite;
DROP INDEX IF EXISTS idx_cache_filters_nome_composite;
DROP INDEX IF EXISTS idx_cache_filters_cidade_composite;

-- Main composite index (already existed but ensuring it's optimal)
CREATE INDEX idx_cache_filters_composite
ON public.cache_filters (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);

-- Specialized indexes for the heavy dropdown queries
-- Pattern: (Column being aggregated) + (Most common filter columns)

CREATE INDEX IF NOT EXISTS idx_cache_filters_superv_lookup
ON public.cache_filters (filial, cidade, ano, superv);

CREATE INDEX IF NOT EXISTS idx_cache_filters_nome_lookup
ON public.cache_filters (filial, cidade, superv, ano, nome);

CREATE INDEX IF NOT EXISTS idx_cache_filters_cidade_lookup
ON public.cache_filters (filial, ano, cidade);

-- 2. Optimize Cache Refresh Function
-- Using TRUNCATE is good, but insertion can be slow if source tables are huge.
-- We optimize the source query.

CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- Limpa o cache atual
    TRUNCATE TABLE public.cache_filters;

    -- Preenche com dados únicos.
    -- Optimization: Group by inside the UNION to reduce data movement
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes)
    SELECT DISTINCT
        filial,
        cidade,
        superv,
        nome,
        codfor,
        fornecedor,
        tipovenda,
        yr,
        mth
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
