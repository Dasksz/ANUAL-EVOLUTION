
-- Fix Ambiguous Column and Category Filter Logic in Main Dashboard RPC
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
    p_categoria text[] default null
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
    v_where_base text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_result json;

    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_daily_data_current json;
    v_daily_data_previous json;
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
        v_is_month_filtered := true;
    ELSE
         SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year;
         v_is_month_filtered := false;
    END IF;

    -- 2. Trend Logic Calculation
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
           v_rede_condition := format('ramo = ANY(%L)', v_specific_redes);
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
        v_mix_constraint := ' fs.codfor IN (''707'', ''708'') ';
    END IF;

    -- KPI Base Filter (Table: data_clients)
    v_where_kpi := ' WHERE bloqueio != ''S'' ';
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    -- FILIAL LOGIC FOR KPI
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        SELECT array_agg(DISTINCT cidade) INTO v_filial_cities
        FROM public.config_city_branches
        WHERE filial = ANY(p_filial);

        IF v_filial_cities IS NOT NULL THEN
             v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', v_filial_cities);
        ELSE
             v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- SUPERVISOR LOGIC FOR KPI
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        SELECT array_agg(DISTINCT d.codusur) INTO v_supervisor_rcas
        FROM public.data_detailed d
        JOIN public.dim_supervisores ds ON d.codsupervisor = ds.codigo
        WHERE ds.nome = ANY(p_supervisor);

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
           v_rede_condition := format('ramo = ANY(%L)', v_specific_redes);
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
    -- Logic Split: If Month is filtered, we need Daily Data. If not, only Monthly.
    -- To optimize, if Month Filter is active, we add a CTE for daily agg.

    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda, codfor, categoria_produto
        FROM public.data_summary
        ' || v_where_base || '
    ),
    monthly_client_agg AS (
        SELECT ano, mes, codcli
        FROM filtered_summary
        WHERE (
            CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1)
                ELSE tipovenda NOT IN (''5'', ''11'')
            END
        )
        GROUP BY ano, mes, codcli
        HAVING (
            ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
            OR
            ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
        )
    ),
    monthly_counts AS (
        SELECT ano, mes, COUNT(*) as active_count
        FROM monthly_client_agg
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
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) THEN fs.peso ELSE 0 END
                ELSE
                    CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                             CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso ELSE 0 END
                        WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso
                        ELSE 0
                    END
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

            COALESCE(mc.active_count, 0) as positivacao_count,

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
        GROUP BY fs.ano, fs.mes, mc.active_count
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
            SELECT codcli
            FROM filtered_summary
            WHERE ano = $2
            ' || CASE WHEN v_is_month_filtered THEN ' AND mes = $3 ' ELSE '' END || '
            AND (
                CASE
                    WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1)
                    ELSE tipovenda NOT IN (''5'', ''11'')
                END
            )
            GROUP BY codcli
            HAVING (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
            )
        ) t
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients
        ' || v_where_kpi || '
    )';

    -- Add Daily Aggregation Logic (Conditionally)
    IF v_is_month_filtered THEN
        -- We need raw data for daily aggregation, data_summary is monthly.
        -- So we query data_detailed/data_history based on filters.
        -- Reuse v_where_base logic but apply to raw tables context if possible?
        -- Actually, data_summary filters (filial, cidade, supervisor codes) map directly.
        -- BUT we need granular day info.

        -- Optimized: Raw Data Query for Daily Chart
        -- We construct a WHERE clause for raw tables similar to summary
        -- NOTE: Using materialized view or direct table access? Direct tables with indexes.

        DECLARE
            v_raw_where text := ' WHERE 1=1 ';
        BEGIN
            -- Reconstruct minimal where for raw tables using same params
            IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND filial = ANY(%L) ', p_filial); END IF;
            IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND cidade = ANY(%L) ', p_cidade); END IF;
            IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor); END IF;
            IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor); END IF;
            -- FIXED: Added aliases 's' to avoid ambiguity in dynamic SQL
            IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND s.codfor = ANY(%L) ', p_fornecedor); END IF;
            IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_raw_where := v_raw_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

            -- Category (Need join for this in raw tables)
            -- If category is used, we need to join dim_produtos
            -- v_raw_where will handle standard columns.
            -- Complex Rede logic also needs handling.

            v_sql := v_sql || ',
            daily_raw AS (
                SELECT dtped, vlvenda, totpesoliq, bonificacao, tipovenda
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente -- Need clients for Rede logic
                ' || v_raw_where || '
                AND EXTRACT(MONTH FROM dtped) = $3
                AND EXTRACT(YEAR FROM dtped) IN ($2, $4)
                ' || CASE WHEN p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN format(' AND dp.categoria_produto = ANY(%L) ', p_categoria) ELSE '' END || '
                ' || CASE WHEN v_rede_condition != '' THEN ' AND (' || v_rede_condition || ') ' ELSE '' END || '

                UNION ALL

                SELECT dtped, vlvenda, totpesoliq, bonificacao, tipovenda
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
                ' || v_raw_where || '
                AND EXTRACT(MONTH FROM dtped) = $3
                AND EXTRACT(YEAR FROM dtped) IN ($2, $4)
                ' || CASE WHEN p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN format(' AND dp.categoria_produto = ANY(%L) ', p_categoria) ELSE '' END || '
                ' || CASE WHEN v_rede_condition != '' THEN ' AND (' || v_rede_condition || ') ' ELSE '' END || '
            ),
            daily_agg AS (
                SELECT
                    EXTRACT(YEAR FROM dtped)::int as yr,
                    EXTRACT(DAY FROM dtped)::int as dy,
                    SUM(CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                            CASE WHEN tipovenda = ANY($1) THEN vlvenda ELSE 0 END
                        WHEN tipovenda IN (''1'', ''9'') THEN vlvenda
                        ELSE 0
                    END) as faturamento,
                    SUM(CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                             CASE WHEN tipovenda = ANY($1) THEN totpesoliq ELSE 0 END
                        ELSE
                            CASE
                                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                                     CASE WHEN tipovenda = ANY($1) AND tipovenda NOT IN (''5'', ''11'') THEN totpesoliq ELSE 0 END
                                WHEN tipovenda NOT IN (''5'', ''11'') THEN totpesoliq
                                ELSE 0
                            END
                    END) as peso,
                    SUM(CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 && ARRAY[''5'',''11'']) THEN
                             CASE WHEN tipovenda = ANY($1) AND tipovenda IN (''5'', ''11'') THEN bonificacao ELSE 0 END
                        ELSE
                             CASE WHEN tipovenda IN (''5'', ''11'') THEN bonificacao ELSE 0 END
                    END) as bonificacao
                FROM daily_raw
                GROUP BY 1, 2
            ) ';
        END;
    ELSE
        -- No daily CTE needed
        v_sql := v_sql || ', daily_agg AS (SELECT null::int as yr, null::int as dy, null::numeric as faturamento, null::numeric as peso, null::numeric as bonificacao WHERE 1=0) ';
    END IF;

    -- Final Select
    v_sql := v_sql || '
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        (
            SELECT COALESCE(json_agg(json_build_object(
                ''month_index'', a.mes - 1,
                ''faturamento'', a.faturamento,
                ''total_sold_base'', a.total_sold_base,
                ''peso'', a.peso,
                ''bonificacao'', a.bonificacao,
                ''devolucao'', a.devolucao,
                ''positivacao'', a.positivacao_count,
                ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
                ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
            ) ORDER BY a.mes), ''[]''::json)
            FROM agg_data a
            WHERE a.ano = $2
        ),
        (
            SELECT COALESCE(json_agg(json_build_object(
                ''month_index'', a.mes - 1,
                ''faturamento'', a.faturamento,
                ''total_sold_base'', a.total_sold_base,
                ''peso'', a.peso,
                ''bonificacao'', a.bonificacao,
                ''devolucao'', a.devolucao,
                ''positivacao'', a.positivacao_count,
                ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
                ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
            ) ORDER BY a.mes), ''[]''::json)
            FROM agg_data a
            WHERE a.ano = $4
        ),
        (
            SELECT COALESCE(json_agg(json_build_object(
                ''day'', da.dy,
                ''faturamento'', da.faturamento,
                ''peso'', da.peso,
                ''bonificacao'', da.bonificacao
            ) ORDER BY da.dy), ''[]''::json)
            FROM daily_agg da
            WHERE da.yr = $2
        ),
        (
            SELECT COALESCE(json_agg(json_build_object(
                ''day'', da.dy,
                ''faturamento'', da.faturamento,
                ''peso'', da.peso,
                ''bonificacao'', da.bonificacao
            ) ORDER BY da.dy), ''[]''::json)
            FROM daily_agg da
            WHERE da.yr = $4
        )
    ';

    EXECUTE v_sql
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous, v_daily_data_current, v_daily_data_previous
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

    SELECT json_agg(date) INTO v_holidays FROM public.data_holidays;

    v_result := json_build_object(
        'current_year', v_current_year,
        'previous_year', v_previous_year,
        'target_month_index', v_target_month - 1,
        'kpi_clients_attended', COALESCE(v_kpi_clients_attended, 0),
        'kpi_clients_base', COALESCE(v_kpi_clients_base, 0),
        'monthly_data_current', v_monthly_chart_current,
        'monthly_data_previous', v_monthly_chart_previous,
        'daily_data_current', v_daily_data_current,
        'daily_data_previous', v_daily_data_previous,
        'trend_data', v_trend_data,
        'trend_allowed', v_trend_allowed,
        'holidays', COALESCE(v_holidays, '[]'::json)
    );
    RETURN v_result;
END;
$$;
