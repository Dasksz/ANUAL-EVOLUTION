-- Fix permissions for cache refresh functions
-- These functions need SECURITY DEFINER to run with owner privileges (to TRUNCATE tables)

-- Refresh Filters Cache Function
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede)
    SELECT DISTINCT
        t.filial,
        COALESCE(t.cidade, c.cidade) as cidade,
        ds.nome as superv,
        COALESCE(dv.nome, c.nomecliente) as nome,
        t.codfor,
        df.nome as fornecedor,
        t.tipovenda,
        t.yr,
        t.mth,
        c.ramo as rede
    FROM (
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codvendedor = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo;
END;
$$;

-- Refresh Summary Cache Function (Optimized with Mix Products Array)
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

    CLUSTER public.data_summary USING idx_summary_ano_filial;
    ANALYZE public.data_summary;
END;
$$;

-- Refresh Cache & Summary Function (Legacy Wrapper)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM refresh_cache_filters();
    PERFORM refresh_cache_summary();
END;
$$;
