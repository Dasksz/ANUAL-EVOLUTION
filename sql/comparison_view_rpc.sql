
-- RPC for Comparison View (Optimized for Performance & Completeness)
CREATE OR REPLACE FUNCTION get_comparison_view_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    -- Date Ranges
    v_ref_date date;
    v_start_target timestamp with time zone;
    v_end_target timestamp with time zone;
    v_start_quarter timestamp with time zone;
    v_end_quarter timestamp with time zone;

    -- Filter Clause
    v_where text := ' WHERE 1=1 ';
    v_where_rede text := '';

    -- Outputs
    v_current_kpi json;
    v_history_kpi json;
    v_current_daily json;
    v_history_daily json;
    v_supervisor_data json;
    v_history_monthly json;

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    -- Security Check
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    -- 1. Date Logic (Mirrors JS fetchComparisonData)
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        IF p_mes IS NOT NULL AND p_mes != '' THEN
            -- Year + Month Selected
            v_ref_date := make_date(p_ano::int, p_mes::int + 1, 15); -- Mid-month
            v_end_target := (make_date(p_ano::int, p_mes::int + 1, 1) + interval '1 month' - interval '1 second');
        ELSE
            -- Year Selected, No Month -> Use Dec 31 of that year OR Current Date if Current Year
            IF p_ano::int = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
                v_ref_date := CURRENT_DATE;
            ELSE
                v_ref_date := make_date(p_ano::int, 12, 31);
            END IF;
            v_end_target := (v_ref_date + interval '1 day' - interval '1 second'); -- End of ref day approx
        END IF;
    ELSE
        -- No Year -> Default to Last Sales Date or Now (We use Now/Max DB Date)
        SELECT MAX(dtped) INTO v_end_target FROM public.data_detailed;
        IF v_end_target IS NULL THEN v_end_target := now(); END IF;
        v_ref_date := v_end_target::date;
    END IF;

    -- Calculate Start/End
    v_start_target := date_trunc('month', v_ref_date);
    v_end_target := (v_start_target + interval '1 month' - interval '1 second');

    -- Comparison Quarter (Previous 3 Months)
    v_end_quarter := v_start_target - interval '1 second';
    v_start_quarter := date_trunc('month', v_end_quarter - interval '2 months');

    -- 2. Build WHERE Clause
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        -- Handle Special Fornecedor Groups if needed, or assume raw codes
        -- JS logic handled "ELMA", "FOODS" etc by codes. Here we assume p_fornecedor contains codes.
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;

    -- REDE Logic (Requires Join with Clients or Ramo check if denormalized)
    -- data_detailed/history do NOT have 'ramo'. We must join data_clients.
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('c.ramo = ANY(%L)', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NOT NULL AND c.ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NULL OR c.ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_rede := ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Aggregation Queries (Optimized with CTEs)

    EXECUTE format('
        WITH target_sales AS (
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_detailed s %s %s AND dtped >= %L AND dtped <= %L
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_history s %s %s AND dtped >= %L AND dtped <= %L
        ),
        history_sales AS (
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_detailed s %s %s AND dtped >= %L AND dtped <= %L
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_history s %s %s AND dtped >= %L AND dtped <= %L
        ),
        -- Current Aggregates
        curr_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM target_sales GROUP BY 1
        ),
        -- Current Mix Calculation (Active Clients Filter: Sum Venda >= 1)
        curr_mix_base AS (
            SELECT
                codcli,
                SUM(vlvenda) as total_val,
                COUNT(DISTINCT CASE WHEN codfor IN (''707'', ''708'') AND vlvenda > 0 THEN produto END) as pepsico_skus,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%CHEETOS%%'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%DORITOS%%'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%FANDANGOS%%'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%RUFFLES%%'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TORCIDA%%'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TODDYNHO%%'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TODDY %%'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%QUAKER%%'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%KEROCOCO%%'' THEN 1 ELSE 0 END) as has_kerococo
            FROM target_sales
            GROUP BY 1
        ),
        curr_kpi AS (
            SELECT
                SUM(ts.vlvenda) as f,
                SUM(ts.totpesoliq) as p,
                (SELECT COUNT(*) FROM curr_mix_base WHERE total_val >= 1) as c,
                COALESCE((SELECT SUM(pepsico_skus)::numeric / NULLIF(COUNT(CASE WHEN pepsico_skus > 0 THEN 1 END), 0) FROM curr_mix_base), 0) as mix_pepsico,
                COALESCE((SELECT COUNT(1) FROM curr_mix_base WHERE has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1), 0) as pos_salty,
                COALESCE((SELECT COUNT(1) FROM curr_mix_base WHERE has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1), 0) as pos_foods
            FROM target_sales ts
        ),
        curr_superv AS (
            SELECT codsupervisor as s, SUM(vlvenda) as f FROM target_sales GROUP BY 1
        ),
        -- History Aggregates
        hist_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM history_sales GROUP BY 1
        ),
        -- History Mix Calculation (Monthly)
        hist_monthly_mix AS (
            SELECT
                date_trunc(''month'', dtped) as m_date,
                codcli,
                SUM(vlvenda) as total_val,
                COUNT(DISTINCT CASE WHEN codfor IN (''707'', ''708'') AND vlvenda > 0 THEN produto END) as pepsico_skus,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%CHEETOS%%'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%DORITOS%%'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%FANDANGOS%%'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%RUFFLES%%'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TORCIDA%%'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TODDYNHO%%'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%TODDY %%'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%QUAKER%%'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN vlvenda > 0 AND descricao ILIKE ''%%KEROCOCO%%'' THEN 1 ELSE 0 END) as has_kerococo
            FROM history_sales
            GROUP BY 1, 2
        ),
        hist_monthly_sums AS (
            SELECT
                m_date,
                SUM(total_val) as monthly_f,
                COUNT(CASE WHEN total_val >= 1 THEN 1 END) as monthly_active_clients,
                COALESCE(SUM(pepsico_skus)::numeric / NULLIF(COUNT(CASE WHEN pepsico_skus > 0 THEN 1 END), 0), 0) as monthly_mix_pepsico,
                COUNT(CASE WHEN has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1 THEN 1 END) as monthly_pos_salty,
                COUNT(CASE WHEN has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1 THEN 1 END) as monthly_pos_foods
            FROM hist_monthly_mix
            GROUP BY 1
        ),
        hist_kpi AS (
            SELECT
                SUM(ts.vlvenda) as f,
                SUM(ts.totpesoliq) as p,
                COALESCE((SELECT SUM(monthly_active_clients) FROM hist_monthly_sums), 0) as c,
                COALESCE((SELECT SUM(monthly_mix_pepsico) FROM hist_monthly_sums), 0) as sum_mix_pepsico,
                COALESCE((SELECT SUM(monthly_pos_salty) FROM hist_monthly_sums), 0) as sum_pos_salty,
                COALESCE((SELECT SUM(monthly_pos_foods) FROM hist_monthly_sums), 0) as sum_pos_foods
            FROM history_sales ts
        ),
        hist_superv AS (
            SELECT codsupervisor as s, SUM(vlvenda) as f FROM history_sales GROUP BY 1
        ),
        hist_monthly AS (
             SELECT to_char(m_date, ''YYYY-MM'') as m, monthly_f as f, monthly_active_clients as c
             FROM hist_monthly_sums
        )
        SELECT
            COALESCE((SELECT json_agg(row_to_json(curr_daily.*)) FROM curr_daily), ''[]''),
            COALESCE((SELECT row_to_json(curr_kpi.*) FROM curr_kpi), ''{}''),
            COALESCE((SELECT json_agg(row_to_json(hist_daily.*)) FROM hist_daily), ''[]''),
            COALESCE((SELECT row_to_json(hist_kpi.*) FROM hist_kpi), ''{}''),
            COALESCE((SELECT json_agg(json_build_object(
                ''name'', COALESCE(ds.nome, ''Outros''),
                ''current'', COALESCE(cs.f, 0),
                ''history'', COALESCE(hs.f, 0)
            ))
            FROM (SELECT DISTINCT s FROM curr_superv UNION SELECT DISTINCT s FROM hist_superv) all_s
            LEFT JOIN curr_superv cs ON all_s.s = cs.s
            LEFT JOIN hist_superv hs ON all_s.s = hs.s
            LEFT JOIN public.dim_supervisores ds ON all_s.s = ds.codigo
            ), ''[]''),
            COALESCE((SELECT json_agg(row_to_json(hist_monthly.*)) FROM hist_monthly), ''[]'')
    ',
    v_where, v_where_rede, v_start_target, v_end_target,
    v_where, v_where_rede, v_start_target, v_end_target,
    v_where, v_where_rede, v_start_quarter, v_end_quarter,
    v_where, v_where_rede, v_start_quarter, v_end_quarter
    ) INTO v_current_daily, v_current_kpi, v_history_daily, v_history_kpi, v_supervisor_data, v_history_monthly;

    RETURN json_build_object(
        'current_daily', v_current_daily,
        'current_kpi', v_current_kpi,
        'history_daily', v_history_daily,
        'history_kpi', v_history_kpi,
        'supervisor_data', v_supervisor_data,
        'history_monthly', v_history_monthly,
        'debug_range', json_build_object('start', v_start_target, 'end', v_end_target, 'h_start', v_start_quarter, 'h_end', v_end_quarter)
    );
END;
$$;
