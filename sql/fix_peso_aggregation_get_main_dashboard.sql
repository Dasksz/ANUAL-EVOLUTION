-- =========================================================================================
-- MIGRAÇÃO: Correção da agregação da "TON VENDIDA" (peso) na função get_main_dashboard_data
-- DESCRIÇÃO: Ajusta a lógica de soma de pesos para que ao filtrar múltiplos tipos de vendas
-- (incluindo 5 e 11), a soma obedeça estritamente os tipos filtrados, sem zerar 5 e 11.
-- O comportamento padrão quando vazio (sem filtros) permanece ignorando as vendas 5 e 11.
-- =========================================================================================

CREATE OR REPLACE FUNCTION get_main_dashboard_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
    p_categoria text[] default null -- Added
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_eval_target_month int;

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

    v_where_base text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_result json;
    v_sql text;

    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_curr_month_idx int;

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
    v_is_month_filtered boolean := false;

    -- Mix Logic Vars
    v_mix_constraint text;

    -- New KPI Logic Vars
    v_filial_cities text[];
    v_supervisor_rcas text[];
    v_vendedor_rcas text[];
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '600s';

    -- 1. Determine Date Ranges
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary);
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_is_month_filtered := true;
    ELSE
         v_target_month := (SELECT COALESCE(MAX(mes), 12) FROM public.data_summary WHERE ano = v_current_year);
         v_is_month_filtered := false;
    END IF;

    -- 2. Trend Logic Calculation
    v_max_sale_date := (SELECT MAX(dtped)::date FROM public.data_detailed);
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

    v_where_base := v_where_base || format(' AND ano IN (%L, %L) ', v_current_year, v_previous_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_base := v_where_base || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('UPPER(ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x))', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NULL OR ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_base := v_where_base || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- MIX Constraint Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_mix_constraint := ' 1=1 ';
    ELSE
        v_mix_constraint := ' fs.codfor IN (''707'', ''708'', ''752'') ';
    END IF;

    -- KPI Base Filter (Table: data_clients)
    v_where_kpi := ' WHERE bloqueio != ''S'' ';
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    -- FILIAL LOGIC FOR KPI
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            SELECT array_agg(DISTINCT cidade) INTO v_filial_cities
            FROM public.config_city_branches
            WHERE filial = ANY(p_filial);

            IF v_filial_cities IS NOT NULL THEN
                 v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', v_filial_cities);
            ELSE
                 v_where_kpi := v_where_kpi || ' AND 1=0 ';
            END IF;
        END IF;
    END IF;

    -- SUPERVISOR LOGIC FOR KPI
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        SELECT array_agg(DISTINCT rs.codusur) INTO v_supervisor_rcas
        FROM (
            SELECT codusur, codsupervisor,
                   ROW_NUMBER() OVER(PARTITION BY codusur ORDER BY dtped DESC) as rn
            FROM (
                SELECT codusur, codsupervisor, dtped FROM public.data_detailed
                UNION ALL
                SELECT codusur, codsupervisor, dtped FROM public.data_history
            ) all_sales
        ) rs
        JOIN public.dim_supervisores ds ON rs.codsupervisor = ds.codigo
        WHERE rs.rn = 1 AND ds.nome = ANY(p_supervisor);

        IF v_supervisor_rcas IS NOT NULL THEN
            v_where_kpi := v_where_kpi || format(' AND rca1 = ANY(%L) ', v_supervisor_rcas);
        ELSE
             v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- VENDEDOR LOGIC FOR KPI
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        SELECT array_agg(DISTINCT codigo) INTO v_vendedor_rcas
        FROM public.dim_vendedores
        WHERE nome = ANY(p_vendedor);

        IF v_vendedor_rcas IS NOT NULL THEN
            v_where_kpi := v_where_kpi || format(' AND rca1 = ANY(%L) ', v_vendedor_rcas);
        ELSE
            v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- REDE KPI
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_rede_condition := ''; -- reset
        IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('UPPER(ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x))', v_specific_redes);
        END IF;
        IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND ramo NOT IN (''N/A'', ''N/D'')) ';
        END IF;
        IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NULL OR ramo IN (''N/A'', ''N/D'')) ';
        END IF;
        IF v_rede_condition != '' THEN
            v_where_kpi := v_where_kpi || ' AND (' || v_rede_condition || ') ';
        END IF;
    END IF;

    -- 4. Execute Main Aggregation Query
    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, tipovenda, vlvenda, peso, bonificacao, devolucao, codcli, pre_mix_count, codfor
        FROM public.data_summary_frequency fs
        ' || v_where_base || '
    ),
    monthly_counts AS (
        SELECT
            ano, mes,
            COUNT(DISTINCT CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                    CASE WHEN tipovenda = ANY($1) AND bonificacao > 0 THEN codcli ELSE NULL END
                ELSE
                    CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                            CASE WHEN tipovenda = ANY($1) AND vlvenda >= 1 THEN codcli ELSE NULL END
                        WHEN vlvenda >= 1 THEN codcli
                        ELSE NULL
                    END
            END) as active_count
        FROM filtered_summary
        GROUP BY ano, mes
    ),
    agg_data AS (
        SELECT
            fs.ano,
            fs.mes,
            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.vlvenda ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') THEN fs.vlvenda
                ELSE 0
            END) as faturamento,

            SUM(CASE
                WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.vlvenda
                ELSE 0
            END) as total_sold_base,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                     CASE WHEN fs.tipovenda = ANY($1) THEN fs.peso ELSE 0 END
                WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso
                ELSE 0
            END) as peso,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 && ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
                ELSE
                     CASE WHEN fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
            END) as bonificacao,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.devolucao ELSE 0 END
                ELSE fs.devolucao
            END) as devolucao,

            COALESCE(MAX(mc.active_count), 0) as positivacao_count,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.pre_mix_count ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') AND (' || v_mix_constraint || ') THEN fs.pre_mix_count
                ELSE 0
            END) as total_mix_sum,

            COUNT(DISTINCT CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) AND fs.pre_mix_count > 0 THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.codcli ELSE NULL END
                WHEN fs.tipovenda IN (''1'', ''9'') AND fs.pre_mix_count > 0 AND (' || v_mix_constraint || ') THEN fs.codcli
                ELSE NULL
            END) as mix_client_count
        FROM filtered_summary fs
        LEFT JOIN monthly_counts mc ON fs.ano = mc.ano AND fs.mes = mc.mes
        GROUP BY fs.ano, fs.mes
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
            SELECT codcli
            FROM filtered_summary
            WHERE ano = $2
            ' || CASE WHEN v_is_month_filtered THEN ' AND mes = $3 ' ELSE '' END || '
            AND (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND tipovenda = ANY($1) )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND
                  (CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1) ELSE tipovenda NOT IN (''5'', ''11'') END)
                )
            )
            GROUP BY codcli
            HAVING (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
            )
        ) grouped_active_clients
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients
        ' || v_where_kpi || '
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $2), ''[]''::json),

        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $4), ''[]''::json)
    FROM agg_data a
    ';

    EXECUTE v_sql
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    USING p_tipovenda, v_current_year, v_target_month, v_previous_year;

    -- 5. Calculate Trend (Post-Processing)
    IF v_trend_allowed THEN
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;

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

    v_holidays := (SELECT json_agg(date) FROM public.data_holidays);

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
