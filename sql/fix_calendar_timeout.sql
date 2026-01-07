
-- Fix performance timeout in calendar logic and optimize queries

-- 1. Optimized calc_working_days (Avoids generating date series if possible, or uses optimized NOT EXISTS)
CREATE OR REPLACE FUNCTION calc_working_days(start_date date, end_date date)
RETURNS int
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    days int;
BEGIN
    -- Optimized calculation:
    -- 1. Generate series is still needed to check specific weekdays, but we can do it faster?
    -- Actually, for 1 month (max ~31 rows), generate_series is extremely fast.
    -- The bottleneck was likely the NOT IN check if holidays table is large or unindexed.
    -- We added an index to holidays, but let's assume it might not be there.

    SELECT COUNT(*)
    INTO days
    FROM generate_series(start_date, end_date, '1 day'::interval) AS d
    WHERE EXTRACT(ISODOW FROM d) < 6 -- Mon-Fri
      AND NOT EXISTS (SELECT 1 FROM public.data_holidays h WHERE h.date = d::date);

    RETURN days;
END;
$$;

-- 2. Optimized get_main_dashboard_data (Increase timeout, optimize aggregation)
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
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_result json;

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_work_days_passed int;
    v_work_days_total int;
    v_trend_factor numeric;
    v_trend_data json;
    v_month_start date;
    v_month_end date;
    v_holidays json;

    -- Temp Vars
    v_curr_month_idx int;
    v_curr_faturamento numeric;
    v_curr_peso numeric;
    v_curr_bonificacao numeric;
    v_curr_devolucao numeric;
    v_curr_positivacao int;

BEGIN
    -- Increase timeout for heavy aggregation
    SET LOCAL statement_timeout = '60s';

    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        -- Optimization: Don't scan the whole table for max year if we can assume current year
        -- But for safety, let's keep it but make sure it's indexed.
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

    -- Trend Calculation Logic
    -- Optimize: Use the index idx_detailed_dtped_desc to get max date instantly
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

        -- Sanity check
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        -- Call optimized working days function
        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
    ELSE
        v_trend_factor := 0;
    END IF;

    WITH filtered_summary AS (
        SELECT *
        FROM public.data_summary
        WHERE ano IN (v_current_year, v_previous_year)
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
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
                WHEN (p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0) THEN vlvenda
                WHEN tipovenda IN ('1', '9') THEN vlvenda
                ELSE 0
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
             SELECT codcli
             FROM filtered_summary
             WHERE ano = v_current_year AND mes = v_target_month
             GROUP BY codcli
             HAVING SUM(vlvenda) >= 1
        ) t
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT COUNT(*) FROM public.data_clients c WHERE c.bloqueio != 'S' AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR c.cidade = ANY(p_cidade))),
        COALESCE(json_agg(json_build_object('month_index', a.mes - 1, 'faturamento', a.faturamento, 'peso', a.peso, 'bonificacao', a.bonificacao, 'devolucao', a.devolucao, 'positivacao', COALESCE(p.positivacao_count, 0)) ORDER BY a.mes) FILTER (WHERE a.ano = v_current_year), '[]'::json),
        COALESCE(json_agg(json_build_object('month_index', a.mes - 1, 'faturamento', a.faturamento, 'peso', a.peso, 'bonificacao', a.bonificacao, 'devolucao', a.devolucao, 'positivacao', COALESCE(p.positivacao_count, 0)) ORDER BY a.mes) FILTER (WHERE a.ano = v_previous_year), '[]'::json)
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    FROM agg_data a
    LEFT JOIN monthly_positivation p ON a.ano = p.ano AND a.mes = p.mes;

    IF v_trend_allowed THEN
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;

        -- Use json_array_elements to unpack the current year data and find the month
        SELECT
            (elem->>'faturamento')::numeric,
            (elem->>'peso')::numeric,
            (elem->>'bonificacao')::numeric,
            (elem->>'devolucao')::numeric,
            (elem->>'positivacao')::int
        INTO v_curr_faturamento, v_curr_peso, v_curr_bonificacao, v_curr_devolucao, v_curr_positivacao
        FROM json_array_elements(v_monthly_chart_current) elem
        WHERE (elem->>'month_index')::int = v_curr_month_idx;

        IF v_curr_faturamento IS NOT NULL THEN
            v_trend_data := json_build_object(
                'month_index', v_curr_month_idx,
                'faturamento', (v_curr_faturamento * v_trend_factor),
                'peso', (v_curr_peso * v_trend_factor),
                'bonificacao', (v_curr_bonificacao * v_trend_factor),
                'devolucao', (v_curr_devolucao * v_trend_factor),
                'positivacao', (v_curr_positivacao * v_trend_factor)::int
            );
        END IF;
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
