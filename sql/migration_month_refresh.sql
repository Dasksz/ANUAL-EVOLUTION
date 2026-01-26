-- Migration: Add refresh_summary_month function and optimize cache refresh logic
-- Use this script to patch an existing database to avoid timeouts.

-- 1. Optimize Year Fetching (Avoids Sequence Scans on large tables)
CREATE OR REPLACE FUNCTION get_available_years()
RETURNS int[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    min_year int;
    max_year int;
    years int[];
BEGIN
    -- Get Min/Max from both tables efficiently using indexes
    SELECT
        LEAST(
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_history)
        ),
        GREATEST(
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_history)
        )
    INTO min_year, max_year;

    -- Handle empty tables
    IF min_year IS NULL THEN
        min_year := COALESCE(
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_history),
            EXTRACT(YEAR FROM CURRENT_DATE)::int
        );
    END IF;

    IF max_year IS NULL THEN
        max_year := COALESCE(
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_history),
            EXTRACT(YEAR FROM CURRENT_DATE)::int
        );
    END IF;

    -- Generate series
    SELECT array_agg(y ORDER BY y DESC) INTO years
    FROM generate_series(min_year, max_year) as y;

    RETURN years;
END;
$$;

-- 2. Create Monthly Refresh Function (Granular Logic)
CREATE OR REPLACE FUNCTION refresh_summary_month(p_year int, p_month int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Clear data for this year/month first (avoid duplicates)
    DELETE FROM public.data_summary WHERE ano = p_year AND mes = p_month;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_detailed
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_history
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
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
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda_embalagem_master,
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda_embalagem_master, 0)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        total_caixas
    FROM client_agg;
END;
$$;

-- 3. Update Refresh Filters Cache (Optimized: Analyze first)
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Ensure stats are up to date before complex joins
    ANALYZE public.data_summary;

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede)
    SELECT DISTINCT
        t.filial,
        t.cidade,
        ds.nome as superv,
        dv.nome as nome,
        t.codfor,
        CASE
            WHEN t.codfor = '707' THEN 'EXTRUSADOS'
            WHEN t.codfor = '708' THEN 'Ñ EXTRUSADOS'
            WHEN t.codfor = '752' THEN 'TORCIDA'
            WHEN t.codfor = '1119_TODDYNHO' THEN 'TODDYNHO'
            WHEN t.codfor = '1119_TODDY' THEN 'TODDY'
            WHEN t.codfor = '1119_QUAKER' THEN 'QUAKER'
            WHEN t.codfor = '1119_KEROCOCO' THEN 'KEROCOCO'
            WHEN t.codfor = '1119_OUTROS' THEN 'FOODS (Outros)'
            WHEN t.codfor = '1119' THEN 'FOODS (Outros)'
            ELSE df.nome
        END as fornecedor,
        t.tipovenda,
        t.ano,
        t.mes,
        t.ramo as rede
    FROM public.data_summary t
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codusur = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo;
END;
$$;

-- 4. Update Main Dashboard Cache Refresh (Updated to loop by MONTH)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    r_year int;
    r_month int;
BEGIN
    -- 1. Truncate Main
    TRUNCATE TABLE public.data_summary;

    -- 2. Loop Years and Months
    FOR r_year IN SELECT y FROM unnest(get_available_years()) as y
    LOOP
        FOR r_month IN 1..12
        LOOP
            PERFORM refresh_summary_month(r_year, r_month);
        END LOOP;
    END LOOP;

    -- 3. Refresh Filters
    PERFORM refresh_cache_filters();
END;
$$;
