
-- ==============================================================================
-- FIX RPC SIGNATURES (HOTFIX)
-- Run this script to update function definitions if you are seeing 400 Bad Request
-- ==============================================================================

-- 1. get_main_dashboard_data
CREATE OR REPLACE FUNCTION get_main_dashboard_data(
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
    v_curr_month_idx int;
    
    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    -- Configurações de Memória para esta Query Específica
    SET LOCAL work_mem = '64MB'; -- Aumenta memória para ordenação
    SET LOCAL statement_timeout = '15s'; -- Fail fast se travar

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
    
    -- Base Filters (Table: data_summary)
    v_where_base := v_where_base || format(' AND ano IN (%L, %L) ', v_current_year, v_previous_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    
    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('Com Rede' = ANY(p_rede));
       v_has_sem_rede := ('Sem Rede' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'Com Rede'), 'Sem Rede');
       
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

    -- KPI Base Filter (Table: data_clients)
    v_where_kpi := ' WHERE bloqueio != ''S'' ';
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    
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
    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda
        FROM public.data_summary
        ' || v_where_base || '
    ),
    agg_data AS (
        SELECT
            ano,
            mes,
            SUM(CASE 
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN vlvenda
                WHEN tipovenda IN (''1'', ''9'') THEN vlvenda 
                ELSE 0 
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao,
            COUNT(DISTINCT CASE WHEN pre_positivacao_val = 1 THEN codcli END) as positivacao_count,
            SUM(CASE 
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN pre_mix_count
                WHEN tipovenda IN (''1'', ''9'') THEN pre_mix_count 
                ELSE 0 
            END) as total_mix_sum,
            COUNT(DISTINCT CASE 
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) AND pre_mix_count > 0 THEN codcli 
                WHEN tipovenda IN (''1'', ''9'') AND pre_mix_count > 0 THEN codcli 
                ELSE NULL 
            END) as mix_client_count
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(DISTINCT codcli) as val
        FROM filtered_summary 
        WHERE ano = $2 AND mes = $3 AND pre_positivacao_val = 1
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

    -- 5. Calculate Trend
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
        'trend_data', v_trend_data,
        'trend_allowed', v_trend_allowed,
        'holidays', COALESCE(v_holidays, '[]'::json)
    );
    RETURN v_result;
END;
$$;

-- 2. get_dashboard_filters
CREATE OR REPLACE FUNCTION get_dashboard_filters(
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
SET search_path = public
AS $$
DECLARE
    v_supervisors text[];
    v_vendedores text[];
    v_fornecedores json;
    v_cidades text[];
    v_filiais text[];
    v_anos int[];
    v_tipos_venda text[];
    v_redes text[];
    v_filter_year int;
    v_filter_month int;
BEGIN
    SET LOCAL statement_timeout = '300s';

    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
    ELSE
        IF p_ano = 'todos' THEN v_filter_year := NULL; 
        ELSE
            SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_filter_year FROM public.cache_filters;
        END IF;
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_filter_month := p_mes::int + 1; END IF;

    -- 1. Supervisors
    SELECT ARRAY(SELECT DISTINCT superv FROM public.cache_filters WHERE 
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND superv IS NOT NULL AND superv != '' AND superv != 'null'
        ORDER BY superv
    ) INTO v_supervisors;

    -- 2. Vendedores
    SELECT ARRAY(SELECT DISTINCT nome FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND nome IS NOT NULL AND nome != '' AND nome != 'null'
        ORDER BY nome
    ) INTO v_vendedores;

    -- 3. Cidades
    SELECT ARRAY(SELECT DISTINCT cidade FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND cidade IS NOT NULL AND cidade != '' AND cidade != 'null'
        ORDER BY cidade
    ) INTO v_cidades;

    -- 4. Filiais
    SELECT ARRAY(SELECT DISTINCT filial FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND filial IS NOT NULL AND filial != '' AND filial != 'null'
        ORDER BY filial
    ) INTO v_filiais;

    -- 5. Tipos de Venda
    SELECT ARRAY(SELECT DISTINCT tipovenda FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND tipovenda IS NOT NULL AND tipovenda != '' AND tipovenda != 'null'
        ORDER BY tipovenda
    ) INTO v_tipos_venda;

    -- 6. Fornecedores
    SELECT json_agg(json_build_object('cod', codfor, 'name', CASE WHEN codfor = '707' THEN 'Extrusados' WHEN codfor = '708' THEN 'Ñ Extrusados' WHEN codfor = '752' THEN 'Torcida' WHEN codfor = '1119' THEN 'Foods' ELSE fornecedor END) ORDER BY CASE WHEN codfor = '707' THEN 'Extrusados' WHEN codfor = '708' THEN 'Ñ Extrusados' WHEN codfor = '752' THEN 'Torcida' WHEN codfor = '1119' THEN 'Foods' ELSE fornecedor END) INTO v_fornecedores
    FROM (
        SELECT DISTINCT codfor, fornecedor FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND codfor IS NOT NULL
    ) t;

    -- 7. Redes
    SELECT ARRAY(SELECT DISTINCT rede FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND rede IS NOT NULL AND rede != '' AND rede != 'null' AND rede != 'N/A' AND rede != 'N/D'
        ORDER BY rede
    ) INTO v_redes;

    -- 8. Anos
    SELECT ARRAY(SELECT DISTINCT ano FROM public.cache_filters WHERE
        (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY ano DESC
    ) INTO v_anos;

    RETURN json_build_object(
        'supervisors', COALESCE(v_supervisors, '{}'), 
        'vendedores', COALESCE(v_vendedores, '{}'), 
        'fornecedores', COALESCE(v_fornecedores, '[]'::json), 
        'cidades', COALESCE(v_cidades, '{}'), 
        'filiais', COALESCE(v_filiais, '{}'), 
        'redes', COALESCE(v_redes, '{}'),
        'anos', COALESCE(v_anos, '{}'), 
        'tipos_venda', COALESCE(v_tipos_venda, '{}')
    );
END;
$$;

-- 3. get_city_view_data
CREATE OR REPLACE FUNCTION get_city_view_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_page int default 0,
    p_limit int default 50,
    p_inactive_page int default 0,
    p_inactive_limit int default 50
)
RETURNS JSON
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_target_month int;
    v_where text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE bloqueio != ''S'' ';
    v_sql text;
    v_active_clients json;
    v_inactive_clients json;
    v_total_active_count int;
    v_total_inactive_count int;
    
    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    SET LOCAL work_mem = '64MB';

    -- Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
         SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    -- Target month filter logic for summary
    v_where := v_where || format(' AND ano = %L ', v_current_year);
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_where := v_where || format(' AND mes = %L ', v_target_month);
    END IF;

    -- Dynamic Filters
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    
    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('Com Rede' = ANY(p_rede));
       v_has_sem_rede := ('Sem Rede' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'Com Rede'), 'Sem Rede');
       
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
           -- Apply to summary
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
           -- Apply to clients
           v_where_clients := v_where_clients || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- ACTIVE CLIENTS QUERY
    v_sql := '
    WITH client_totals AS (
        SELECT codcli, SUM(vlvenda) as total_fat
        FROM public.data_summary
        ' || v_where || '
        GROUP BY codcli
        HAVING SUM(vlvenda) >= 1
    ),
    count_cte AS (SELECT COUNT(*) as cnt FROM client_totals),
    paginated_clients AS (
        SELECT ct.codcli, ct.total_fat, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.rca1
        FROM client_totals ct
        JOIN public.data_clients c ON c.codigo_cliente = ct.codcli
        ORDER BY ct.total_fat DESC
        LIMIT $1 OFFSET ($2 * $1)
    )
    SELECT
        (SELECT cnt FROM count_cte),
        json_agg(json_build_object(''Código'', pc.codcli, ''fantasia'', pc.fantasia, ''razaoSocial'', pc.razaosocial, ''totalFaturamento'', pc.total_fat, ''cidade'', pc.cidade, ''bairro'', pc.bairro, ''rca1'', pc.rca1) ORDER BY pc.total_fat DESC)
    FROM paginated_clients pc;
    ';

    EXECUTE v_sql INTO v_total_active_count, v_active_clients USING p_limit, p_page;

    -- INACTIVE CLIENTS QUERY (NOT EXISTS)
    -- We reuse v_where for the NOT EXISTS subquery
    v_sql := '
    WITH inactive_cte AS (
        SELECT c.codigo_cliente, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.ultimacompra, c.rca1
        FROM public.data_clients c
        ' || v_where_clients || '
        AND NOT EXISTS (
              SELECT 1 FROM public.data_summary s2
              ' || v_where || ' AND s2.codcli = c.codigo_cliente
        )
    ),
    count_inactive AS (SELECT COUNT(*) as cnt FROM inactive_cte),
    paginated_inactive AS (
        SELECT * FROM inactive_cte
        ORDER BY ultimacompra DESC NULLS LAST
        LIMIT $1 OFFSET ($2 * $1)
    )
    SELECT
        (SELECT cnt FROM count_inactive),
        json_agg(json_build_object(''Código'', pi.codigo_cliente, ''fantasia'', pi.fantasia, ''razaoSocial'', pi.razaosocial, ''cidade'', pi.cidade, ''bairro'', pi.bairro, ''ultimaCompra'', pi.ultimacompra, ''rca1'', pi.rca1) ORDER BY pi.ultimacompra DESC NULLS LAST)
    FROM paginated_inactive pi;
    ';

    EXECUTE v_sql INTO v_total_inactive_count, v_inactive_clients USING p_inactive_limit, p_inactive_page;

    RETURN json_build_object(
        'active_clients', COALESCE(v_active_clients, '[]'::json),
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', COALESCE(v_inactive_clients, '[]'::json),
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
END;
$$;

-- 4. get_branch_comparison_data
CREATE OR REPLACE FUNCTION get_branch_comparison_data(
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
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_target_month int;

    -- Trend
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_curr_month_idx int;

    -- Dynamic SQL
    v_where text := ' WHERE 1=1 ';
    v_sql text;
    v_result json;
    
    -- Rede Logic
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    SET LOCAL work_mem = '64MB';

    -- 1. Date & Trend Setup (Simplified)
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_target_month := p_mes::int + 1;
    ELSE SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year; END IF;

    -- Trend Calculation (Copy from Main)
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;
    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN v_trend_allowed := false; END IF;
    END IF;

    IF v_trend_allowed THEN
         DECLARE
            v_month_start date := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
            v_month_end date := (v_month_start + interval '1 month' - interval '1 day')::date;
            v_days_passed int := public.calc_working_days(v_month_start, v_max_sale_date);
            v_days_total int := public.calc_working_days(v_month_start, v_month_end);
         BEGIN
            IF v_days_passed > 0 AND v_days_total > 0 THEN v_trend_factor := v_days_total::numeric / v_days_passed::numeric; END IF;
         END;
         v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;
    END IF;

    -- 2. Build Where
    v_where := v_where || format(' AND ano = %L ', v_current_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN v_where := v_where || format(' AND filial = ANY(%L) ', p_filial); END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade); END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN v_where := v_where || format(' AND superv = ANY(%L) ', p_supervisor); END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN v_where := v_where || format(' AND nome = ANY(%L) ', p_vendedor); END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('Com Rede' = ANY(p_rede));
       v_has_sem_rede := ('Sem Rede' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'Com Rede'), 'Sem Rede');
       
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
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- 3. Execute
    v_sql := '
    WITH agg_filial AS (
        SELECT
            filial,
            mes,
            SUM(CASE WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN vlvenda WHEN tipovenda IN (''1'', ''9'') THEN vlvenda ELSE 0 END) as faturamento,
            SUM(peso) as peso
        FROM public.data_summary
        ' || v_where || '
        GROUP BY filial, mes
    )
    SELECT json_object_agg(filial, data)
    FROM (
        SELECT filial, json_build_object(
            ''monthly_data_current'', json_agg(json_build_object(
                ''month_index'', mes - 1,
                ''faturamento'', faturamento,
                ''peso'', peso
            ) ORDER BY mes),
            ''trend_allowed'', $2,
            ''trend_data'', CASE WHEN $2 THEN
                 (SELECT json_build_object(''month_index'', mes - 1, ''faturamento'', faturamento * $3, ''peso'', peso * $3)
                  FROM agg_filial sub
                  WHERE sub.filial = agg_filial.filial AND sub.mes = ($4 + 1))
            ELSE null END
        ) as data
        FROM agg_filial
        GROUP BY filial
    ) t;
    ';

    EXECUTE v_sql INTO v_result USING p_tipovenda, v_trend_allowed, v_trend_factor, v_curr_month_idx;

    RETURN COALESCE(v_result, '{}'::json);
END;
$$;
