-- Optimization: Dynamic SQL, Targeted Indexes, Parallel Execution, and Clustering

-- 1. Optimized Indexes strategy
-- Instead of one giant index, we create targeted indexes for the most common drill-down paths.
-- The base filter is always ANO + MES.

DROP INDEX IF EXISTS public.idx_summary_main;

CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_superv ON public.data_summary (ano, mes, superv);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_nome ON public.data_summary (ano, mes, nome); -- Vendedor
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_cidade ON public.data_summary (ano, mes, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_filial ON public.data_summary (ano, mes, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codfor ON public.data_summary (ano, mes, codfor);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_tipovenda ON public.data_summary (ano, mes, tipovenda);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codcli ON public.data_summary (ano, mes, codcli);

-- 2. Physical Clustering
-- Order data physically by Year/Month/Filial to speed up range scans.
-- Note: This is a one-time operation in this script, but should be run periodically.
-- We use the filial index as it's a common high-level partition.
CLUSTER public.data_summary USING idx_summary_ano_mes_filial;
ANALYZE public.data_summary;

-- 3. Dynamic SQL Function with Parallelism
CREATE OR REPLACE FUNCTION get_main_dashboard_data(
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
    v_current_year int;
    v_previous_year int;
    v_target_month int;

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_work_days_passed int;
    v_work_days_total int;
    v_trend_factor numeric := 0;
    v_trend_data json;
    v_month_start date;
    v_month_end date;
    v_holidays json;

    -- Dynamic SQL
    v_sql text;
    v_where_clause text := '';
    v_result json;

    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_curr_month_idx int;
BEGIN
    -- Force Parallel Execution for Heavy Aggregation
    -- This allows using multiple CPU cores to scan the summary table and unnest arrays
    SET LOCAL max_parallel_workers_per_gather = 4;
    SET LOCAL min_parallel_table_scan_size = '0';
    SET LOCAL statement_timeout = '60s';

    -- 1. Determine Date Ranges
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
    ELSE
         SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year;
    END IF;

    -- 2. Trend Logic Calculation (Lightweight)
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN
           v_trend_allowed := false;
       END IF;
    END IF;

    IF v_trend_allowed THEN
        v_month_start := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;

        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
    END IF;

    -- 3. Construct Dynamic WHERE Clause
    -- This ensures the Query Planner sees exact constraints and uses the targeted indexes.
    v_where_clause := 'WHERE ano IN ($1, $2) ';

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND filial = ANY($3) ';
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND cidade = ANY($4) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND superv = ANY($5) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND nome = ANY($6) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND codfor = ANY($7) ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND tipovenda = ANY($8) ';
    END IF;

    -- 4. Execute Main Aggregation Query
    v_sql := '
    WITH filtered_summary AS (
        SELECT *
        FROM public.data_summary
        ' || v_where_clause || '
    ),
    client_monthly_stats AS (
        SELECT
            ano,
            mes,
            codcli,
            SUM(vlvenda) as total_val
        FROM filtered_summary
        GROUP BY 1, 2, 3
    ),
    monthly_positivation AS (
        SELECT
            ano,
            mes,
            COUNT(DISTINCT codcli) as positivacao_count
        FROM client_monthly_stats
        WHERE total_val >= 1
        GROUP BY 1, 2
    ),
    agg_data AS (
        SELECT
            ano,
            mes,
            SUM(CASE
                WHEN ($8 IS NOT NULL AND array_length($8, 1) > 0) THEN vlvenda
                WHEN tipovenda IN (''1'', ''9'') THEN vlvenda
                ELSE 0
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    mix_eligible_clients AS (
         SELECT ano, mes, codcli
         FROM filtered_summary
         WHERE codfor IN (''707'', ''708'')
         GROUP BY 1, 2, 3
         HAVING SUM(vlvenda) >= 1
    ),
    mix_raw_data AS (
        SELECT
            t.ano,
            t.mes,
            t.codcli,
            COUNT(DISTINCT p) as unique_prods
        FROM filtered_summary t
        JOIN mix_eligible_clients e ON t.ano = e.ano AND t.mes = e.mes AND t.codcli = e.codcli
        CROSS JOIN unnest(t.mix_produtos) p
        WHERE t.codfor IN (''707'', ''708'')
        GROUP BY 1, 2, 3
    ),
    monthly_mix_stats AS (
        SELECT
            ano,
            mes,
            SUM(unique_prods) as total_mix_sum,
            COUNT(codcli) as mix_client_count
        FROM mix_raw_data
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
             SELECT codcli
             FROM filtered_summary
             WHERE ano = $1 AND mes = $9
             GROUP BY codcli
             HAVING SUM(vlvenda) >= 1
        ) t
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients c
        WHERE c.bloqueio != ''S''
        AND ($4 IS NULL OR array_length($4, 1) IS NULL OR c.cidade = ANY($4))
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        COALESCE(json_agg(json_build_object(''month_index'', a.mes - 1, ''faturamento'', a.faturamento, ''peso'', a.peso, ''bonificacao'', a.bonificacao, ''devolucao'', a.devolucao, ''positivacao'', COALESCE(p.positivacao_count, 0), ''mix_pdv'', CASE WHEN mm.mix_client_count > 0 THEN mm.total_mix_sum::numeric / mm.mix_client_count ELSE 0 END, ''ticket_medio'', CASE WHEN COALESCE(p.positivacao_count, 0) > 0 THEN a.faturamento / p.positivacao_count ELSE 0 END) ORDER BY a.mes) FILTER (WHERE a.ano = $1), ''[]''::json),
        COALESCE(json_agg(json_build_object(''month_index'', a.mes - 1, ''faturamento'', a.faturamento, ''peso'', a.peso, ''bonificacao'', a.bonificacao, ''devolucao'', a.devolucao, ''positivacao'', COALESCE(p.positivacao_count, 0), ''mix_pdv'', CASE WHEN mm.mix_client_count > 0 THEN mm.total_mix_sum::numeric / mm.mix_client_count ELSE 0 END, ''ticket_medio'', CASE WHEN COALESCE(p.positivacao_count, 0) > 0 THEN a.faturamento / p.positivacao_count ELSE 0 END) ORDER BY a.mes) FILTER (WHERE a.ano = $2), ''[]''::json)
    FROM agg_data a
    LEFT JOIN monthly_positivation p ON a.ano = p.ano AND a.mes = p.mes
    LEFT JOIN monthly_mix_stats mm ON a.ano = mm.ano AND a.mes = mm.mes
    ';

    EXECUTE v_sql
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    USING v_current_year, v_previous_year, p_filial, p_cidade, p_supervisor, p_vendedor, p_fornecedor, p_tipovenda, v_target_month;

    -- 5. Calculate Trend (Post-Processing)
    IF v_trend_allowed THEN
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;

        -- Extract current month data from the JSON result
        -- This logic is same as before but handling the JSON object in PLPGSQL
        DECLARE
             v_elem json;
        BEGIN
            FOR v_elem IN SELECT * FROM json_array_elements(v_monthly_chart_current)
            LOOP
                IF (v_elem->>'month_index')::int = v_curr_month_idx THEN
                    v_trend_data := json_build_object(
                        'month_index', v_curr_month_idx,
                        'faturamento', (v_elem->>'faturamento')::numeric * v_trend_factor,
                        'peso', (v_elem->>'peso')::numeric * v_trend_factor,
                        'bonificacao', (v_elem->>'bonificacao')::numeric * v_trend_factor,
                        'devolucao', (v_elem->>'devolucao')::numeric * v_trend_factor,
                        'positivacao', ((v_elem->>'positivacao')::numeric * v_trend_factor)::int,
                        'mix_pdv', (v_elem->>'mix_pdv')::numeric,
                        'ticket_medio', (v_elem->>'ticket_medio')::numeric
                    );
                END IF;
            END LOOP;
        END;
    END IF;

    SELECT json_agg(date) INTO v_holidays FROM public.data_holidays;

    v_result := json_build_object(
        'current_year', v_current_year,
        'previous_year', v_previous_year,
        'target_month_index', v_target_month - 1,
        'kpi_clients_attended', COALESCE(v_kpi_clients_attended, 0),
        'kpi_clients_base', COALESCE(v_kpi_clients_base, 0),
        'monthly_data_current', v_monthly_chart_current,
        'monthly_data_previous', v_monthly_chart_previous,
        'trend_data', v_trend_data,
        'trend_allowed', v_trend_allowed,
        'holidays', COALESCE(v_holidays, '[]'::json)
    );
    RETURN v_result;
END;
$$;
