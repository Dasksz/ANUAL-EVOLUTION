
-- ==============================================================================
-- OPTIMIZE STORAGE & PERFORMANCE MIGRATION
-- ==============================================================================

-- 1. Update Functions to Remove Dependencies on Dropped Columns
-- We must update functions FIRST before dropping columns to avoid errors.

-- 1.1 Refresh Filters Cache (Updated to rely on data_clients for missing cols)
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SET search_path = public, extensions, temp
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes)
    SELECT DISTINCT
        t.filial,
        COALESCE(t.cidade, c.cidade) as cidade,
        t.superv,
        COALESCE(t.nome, c.nomecliente) as nome,
        t.codfor,
        t.fornecedor,
        t.tipovenda,
        t.yr,
        t.mth
    FROM (
        -- Select only available columns. 'cidade' is kept. 'nome' (vendor) is kept.
        -- 'cliente_nome', 'bairro', 'descricao' are dropped from source tables.
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente;
END;
$$;

-- 1.2 Refresh Summary Cache (Optimized Mix Count & Removed Dropped Cols)
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
SET search_path = public, extensions, temp
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;

    -- Inserção OTIMIZADA: Já calcula se houve positivação e contagem de mix
    -- NOTA: mix_details e mix_produtos serão removidos da tabela target.
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        -- Removidos mix_produtos e mix_details
        pre_mix_count, pre_positivacao_val
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_history
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            s.filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.superv,
            COALESCE(s.nome, c.nomecliente) as nome,
            s.codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.superv, pa.nome, pa.codfor, pa.tipovenda, pa.codcli,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            -- OPTIMIZED MIX CALCULATION:
            -- Count distinct products (rows in product_agg) where value >= 1 and codfor is relevant
            -- Since product_agg is grouped by product, we just sum up the matches.
            -- This replaces the expensive JSONB creation and parsing.
            SUM(CASE WHEN pa.prod_val >= 1 AND pa.codfor IN ('707', '708') THEN 1 ELSE 0 END) as pre_mix_count
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
    )
    SELECT
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        pre_mix_count,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc
    FROM client_agg;

    CLUSTER public.data_summary USING idx_summary_ano_mes_filial;
    ANALYZE public.data_summary;
END;
$$;


-- 2. Drop Columns to Reduce Storage Size

-- 2.1 data_summary: Remove JSON blobs
ALTER TABLE public.data_summary DROP COLUMN IF EXISTS mix_details;
ALTER TABLE public.data_summary DROP COLUMN IF EXISTS mix_produtos;

-- 2.0 Handle View Dependency (all_sales)
DROP VIEW IF EXISTS public.all_sales;

-- 2.2 data_history: Remove redundant text columns
ALTER TABLE public.data_history DROP COLUMN IF EXISTS cliente_nome;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS bairro;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS descricao;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS observacaofor;
-- KEEP cidade

-- 2.3 data_detailed: Remove redundant text columns
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS cliente_nome;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS bairro;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS descricao;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS observacaofor;
-- KEEP cidade

-- 2.4 Recreate View (Updated Schema)
CREATE OR REPLACE VIEW public.all_sales AS
SELECT * FROM public.data_detailed
UNION ALL
SELECT * FROM public.data_history;


-- 3. Verify Database Integrity (Optional Re-indexing)
-- We rely on existing indexes, but dropping columns is metadata only, so it's fast.
-- The space will be reclaimed on next VACUUM FULL or naturally over time with auto-vacuum.
