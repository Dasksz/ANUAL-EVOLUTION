
-- ==============================================================================
-- HOTFIX: CACHE TIMEOUT FIX
-- Run this script in Supabase SQL Editor to apply the fix immediately.
-- ==============================================================================

-- 1. Update refresh_cache_summary (Remove CLUSTER)
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;

    -- Inserção OTIMIZADA: Já calcula se houve positivação e contagem de mix
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        mix_produtos, mix_details,
        pre_mix_count, pre_positivacao_val,
        ramo
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_history
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            ds.nome as superv,
            COALESCE(dv.nome, c.nomecliente) as nome,
            s.codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto,
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_supervisores ds ON s.codsupervisor = ds.codigo
        LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, ramo, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.superv, pa.nome, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            ARRAY_AGG(DISTINCT pa.produto) FILTER (WHERE pa.produto IS NOT NULL) as arr_prod,
            jsonb_object_agg(pa.produto, pa.prod_val) FILTER (WHERE pa.produto IS NOT NULL) as json_prod
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    )
    SELECT
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        arr_prod, json_prod,
        -- CÁLCULOS PRÉVIOS AQUI:
        (SELECT COUNT(*) FROM jsonb_each_text(json_prod) WHERE (value)::numeric >= 1 AND codfor IN ('707', '708')) as mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo
    FROM client_agg;

    -- CLUSTER removido para evitar timeout no processo automático.
    -- Movido para optimize_database()
    ANALYZE public.data_summary;
END;
$$;

-- 2. Update optimize_database (Add CLUSTER back for manual optimization)
CREATE OR REPLACE FUNCTION optimize_database()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RETURN 'Acesso negado: Apenas administradores podem otimizar o banco.';
    END IF;

    -- Drop heavy indexes if they exist
    DROP INDEX IF EXISTS public.idx_summary_main;

    -- Drop legacy inefficient indexes
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_filial;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_cidade;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_nome;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codfor;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_tipovenda;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codcli;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_ramo;

    -- Recreate targeted optimized indexes (v2)
    CREATE INDEX IF NOT EXISTS idx_summary_composite_main ON public.data_summary (ano, mes, filial, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_comercial ON public.data_summary (superv, nome, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_superv ON public.data_summary (ano, superv);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_nome ON public.data_summary (ano, nome);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codfor ON public.data_summary (ano, codfor);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_tipovenda ON public.data_summary (ano, tipovenda);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codcli ON public.data_summary (ano, codcli);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_ramo ON public.data_summary (ano, ramo);

    -- Re-cluster table for physical order optimization (Manual Only)
    BEGIN
        CLUSTER public.data_summary USING idx_summary_ano_filial;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Ignore clustering errors if any
    END;

    RETURN 'Banco de dados otimizado com sucesso! Índices reconstruídos e tabela reordenada.';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erro ao otimizar banco: ' || SQLERRM;
END;
$$;
