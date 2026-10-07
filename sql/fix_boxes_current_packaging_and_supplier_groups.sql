CREATE OR REPLACE FUNCTION public.get_boxes_dashboard_data(p_filial text[] DEFAULT NULL::text[], p_cidade text[] DEFAULT NULL::text[], p_supervisor text[] DEFAULT NULL::text[], p_vendedor text[] DEFAULT NULL::text[], p_fornecedor text[] DEFAULT NULL::text[], p_ano text DEFAULT NULL::text, p_mes text DEFAULT NULL::text, p_tipovenda text[] DEFAULT NULL::text[], p_rede text[] DEFAULT NULL::text[], p_produto text[] DEFAULT NULL::text[], p_categoria text[] DEFAULT NULL::text[])
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_eval_target_month int;
    v_ref_date date;
    v_tri_start date;
    v_tri_end date;
    v_prod_start_date date;
    v_prod_end_date date;
    
    v_where_summary text := ' WHERE 1=1 ';
    v_where_raw text := ' WHERE 1=1 ';
    v_where_summary_base text := ' WHERE 1=1 ';
    v_where_raw_base text := ' WHERE 1=1 ';
    v_where_dim_produtos text := ' WHERE 1=1 ';
    
    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    -- Boxes use raw quantities and current packaging; summaries can be stale.

    -- Tipovenda cond for clients
    v_tipovenda_client_cond text;
    v_active_client_cond text;
    v_active_client_cond_slow text;
    v_client_activity_sql text;

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_month_start date;
    v_month_end date;
    v_work_days_passed int;
    v_work_days_total int;
    v_curr_month_idx int;
BEGIN
    PERFORM private.evolution_assert_approved();
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '90MB';
    SET LOCAL statement_timeout = '600s';

    -- 1. Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary);
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_ref_date := make_date(v_current_year, v_target_month, 1);
    ELSE
        IF v_current_year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
            v_ref_date := make_date(v_current_year, 12, 1);
        ELSE
             v_ref_date := date_trunc('month', CURRENT_DATE)::date;
        END IF;
    END IF;


    v_tri_end := (v_ref_date - interval '1 day')::date;
    v_tri_start := (v_ref_date - interval '3 months')::date;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_prod_start_date := make_date(v_current_year, v_target_month, 1);
        v_prod_end_date := (v_prod_start_date + interval '1 month')::date;
    ELSE
        v_prod_start_date := make_date(v_current_year, 1, 1);
        v_prod_end_date := make_date(v_current_year + 1, 1, 1);
    END IF;


    -- Trend Logic Calculation
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
        -- Cap max sale date to end of month just in case
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;
    END IF;

    -- 2. Build FILTERS (Keep existing logic)
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND s.produto = ANY(%L::text[]) ', p_produto);
        v_where_raw_base := v_where_raw_base || format(' AND s.produto = ANY(%L::text[]) ', p_produto);
        v_where_dim_produtos := v_where_dim_produtos || format(' AND dp.codigo = ANY(%L::text[]) ', p_produto);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND filial = ANY(%L::text[]) ', p_filial);
        v_where_summary := v_where_summary || format(' AND filial = ANY(%L::text[]) ', p_filial);
        v_where_raw_base := v_where_raw_base || format(' AND filial = ANY(%L::text[]) ', p_filial);
        v_where_summary_base := v_where_summary_base || format(' AND filial = ANY(%L::text[]) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
        v_where_summary := v_where_summary || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
        v_where_raw_base := v_where_raw_base || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
        v_where_summary_base := v_where_summary_base || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
    END IF;
    -- Map Name to Code
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
         v_where_summary := v_where_summary || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
         v_where_raw_base := v_where_raw_base || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
         v_where_summary_base := v_where_summary_base || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
         v_where_summary := v_where_summary || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
         v_where_raw_base := v_where_raw_base || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
         v_where_summary_base := v_where_summary_base || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND tipovenda = ANY(%L::text[]) ', p_tipovenda);
        v_where_raw_base := v_where_raw_base || format(' AND tipovenda = ANY(%L::text[]) ', p_tipovenda);
        v_where_summary := v_where_summary || format(' AND tipovenda = ANY(%L::text[]) ', p_tipovenda);
        v_tipovenda_client_cond := format('tipovenda = ANY(%L::text[])', p_tipovenda);
        IF p_tipovenda <@ ARRAY['5','11'] THEN
            v_active_client_cond := format('tipovenda = ANY(%L::text[]) AND bonificacao > 0', p_tipovenda);
            v_active_client_cond_slow := format('tipovenda = ANY(%L::text[]) AND vlbonific > 0', p_tipovenda);
        ELSE
            v_active_client_cond := format('tipovenda = ANY(%L::text[]) AND tipovenda NOT IN (''5'', ''11'') AND pre_positivacao_val >= 1', p_tipovenda);
            v_active_client_cond_slow := format('tipovenda = ANY(%L::text[]) AND tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1', p_tipovenda);
        END IF;
    ELSE
        v_tipovenda_client_cond := 'tipovenda IN (''1'', ''9'')';
        v_active_client_cond := 'tipovenda NOT IN (''5'', ''11'') AND pre_positivacao_val >= 1';
        v_active_client_cond_slow := 'tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1';
    END IF;
    
    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND categoria_produto = ANY(%L::text[]) ', p_categoria);
        v_where_summary_base := v_where_summary_base || format(' AND categoria_produto = ANY(%L::text[]) ', p_categoria);
        v_where_raw := v_where_raw || format(' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ANY(%L::text[])) ', p_categoria);
        v_where_raw_base := v_where_raw_base || format(' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ANY(%L::text[])) ', p_categoria);
        v_where_dim_produtos := v_where_dim_produtos || format(' AND dp.categoria_produto = ANY(%L::text[]) ', p_categoria);
    END IF;
    
    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND codfor = ANY(%L::text[]) ', p_fornecedor);

        -- Raw Logic (Complex OR/AND for mapped codes)
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ''TODDYNHO''))');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ''TODDY''))');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ''QUAKER''))');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto = ''KEROCOCO''))');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.produto IN (SELECT codigo FROM public.dim_produtos WHERE categoria_produto NOT IN (''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'')))');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;
            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('s.codfor = ANY(%L::text[])', v_simple_codes));
            END IF;
            IF array_length(v_conditions, 1) > 0 THEN
                v_where_raw := v_where_raw || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
                v_where_raw_base := v_where_raw_base || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
                v_where_dim_produtos := v_where_dim_produtos || ' AND (' || replace(replace(array_to_string(v_conditions, ' OR '), 's.codfor', 'dp.codfor'), 's.produto', 'dp.codigo') || ') ';
            END IF;
        END;
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
           v_where_summary := v_where_summary || ' AND (' || v_rede_condition || ') ';
           v_where_raw := v_where_raw || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
           v_where_summary_base := v_where_summary_base || ' AND (' || v_rede_condition || ') ';
           v_where_raw_base := v_where_raw_base || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    v_client_activity_sql := CASE WHEN p_tipovenda IS NOT NULL AND p_tipovenda <@ ARRAY['5','11']
        THEN 'SUM(vlbonific) > 0'
        ELSE 'SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN vlvenda ELSE 0 END) >= 1' END;

    -- 3. Execute Queries

        -- SLOW PATH (Full Raw Data with dim_produtos join)
        -- PERFORMANCE FIX: Materialized CTE to avoid redundant data_history scans
        -- ⚡ QueryTuner: Defer dim_produtos JOIN until AFTER aggregations and filtering in base_data, drastically reducing joined rows from millions to thousands
        EXECUTE format('
            WITH 
            base_data AS MATERIALIZED (
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, s.codcli, s.tipovenda, s.vlbonific, s.codfor
                FROM public.data_detailed s
                %s AND ( (s.dtped >= make_date(%L, 1, 1) AND s.dtped < (make_date(%L, 12, 31) + 1)) OR (s.dtped >= make_date(%L, 1, 1) AND s.dtped < (make_date(%L, 12, 31) + 1)) )
                UNION ALL
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda, s.produto, s.codcli, s.tipovenda, s.vlbonific, s.codfor
                FROM public.data_history s
                %s AND ( (s.dtped >= make_date(%L, 1, 1) AND s.dtped < (make_date(%L, 12, 31) + 1)) OR (s.dtped >= make_date(%L, 1, 1) AND s.dtped < (make_date(%L, 12, 31) + 1)) )
            ),
            client_activity AS (
                SELECT EXTRACT(YEAR FROM dtped)::int AS yr,
                       EXTRACT(MONTH FROM dtped)::int - 1 AS m_idx, codcli
                FROM base_data
                GROUP BY 1, 2, 3
                HAVING %s
            ),
            chart_agg_base AS (
                SELECT 
                    EXTRACT(MONTH FROM dtped)::int - 1 as m_idx,
                    EXTRACT(YEAR FROM dtped)::int as yr,
                    produto,
                    SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                    ARRAY_AGG(DISTINCT CASE WHEN %s THEN codcli END) as client_ids
                FROM base_data s
                GROUP BY 1, 2, 3
            ),
            chart_agg AS (
                SELECT 
                    m_idx, yr, 
                    SUM(fat) as fat, SUM(peso) as peso, SUM(total_qtvenda / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas, (SELECT COUNT(DISTINCT ca.codcli) FROM client_activity ca WHERE ca.m_idx = b.m_idx AND ca.yr = b.yr) as clientes 
                FROM chart_agg_base b
                LEFT JOIN public.dim_produtos dp ON b.produto = dp.codigo
                GROUP BY m_idx, yr
            ),
            kpi_curr_raw AS (
                SELECT 
                    produto,
                    SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                    ARRAY_AGG(DISTINCT CASE WHEN %s THEN codcli END) as client_ids
                FROM base_data s
                WHERE s.dtped >= %L::date AND s.dtped < %L::date %s
                GROUP BY produto
            ),
            kpi_curr AS (
                SELECT 
                    SUM(fat) as fat,
                    SUM(peso) as peso,
                    SUM(total_qtvenda / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas,
                    (SELECT COUNT(DISTINCT ca.codcli) FROM client_activity ca WHERE ca.yr = %L %s) as clientes
                FROM kpi_curr_raw s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            ),
            kpi_prev_raw AS (
                SELECT 
                    produto,
                    SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                    ARRAY_AGG(DISTINCT CASE WHEN %s THEN codcli END) as client_ids
                FROM base_data s
                WHERE s.dtped >= %L::date AND s.dtped < %L::date %s
                GROUP BY produto
            ),
            kpi_prev AS (
                SELECT 
                    SUM(fat) as fat,
                    SUM(peso) as peso,
                    SUM(total_qtvenda / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas,
                    (SELECT COUNT(DISTINCT ca.codcli) FROM client_activity ca WHERE ca.yr = %L %s) as clientes
                FROM kpi_prev_raw s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            ),
            kpi_tri_raw AS (
                SELECT 
                    produto,
                    SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0)) as total_qtvenda
                FROM base_data s
                WHERE s.dtped >= %L::date AND s.dtped < (%L::date + 1)
                GROUP BY produto
            ),
            kpi_tri AS (
                SELECT 
                    SUM(fat) / 3 as fat,
                    SUM(peso) / 3 as peso,
                    SUM(total_qtvenda / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) / 3 as caixas,
                    COALESCE((
                        SELECT SUM(monthly_clients) / 3
                        FROM (
                            SELECT COUNT(DISTINCT CASE WHEN %s THEN sub_s.codcli END) as monthly_clients
                            FROM base_data sub_s
                            WHERE sub_s.dtped >= %L::date AND sub_s.dtped < (%L::date + 1)
                            GROUP BY EXTRACT(YEAR FROM sub_s.dtped), EXTRACT(MONTH FROM sub_s.dtped)
                        ) sub
                    ), 0) as clientes
                FROM kpi_tri_raw s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            ),
            prod_raw AS (
                SELECT produto,
                       SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as faturamento,
                       SUM(totpesoliq) as peso,
                       SUM(COALESCE(qtvenda, 0)) as total_qtvenda,
                       COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes,
                       MAX(dtped) as ultima_venda
                FROM base_data s
                WHERE s.dtped >= %L::date AND s.dtped < %L::date
                GROUP BY produto
            ),
            prod_agg AS (
                SELECT dp.codigo as produto,
                       dp.descricao as descricao,
                       (COALESCE(p.total_qtvenda, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas,
                       COALESCE(p.faturamento, 0) as faturamento,
                       COALESCE(p.peso, 0) as peso,
                       COALESCE(p.clientes, 0) as clientes,
                       p.ultima_venda
                FROM public.dim_produtos dp
                LEFT JOIN prod_raw p ON dp.codigo = p.produto
                %s
                AND (COALESCE(p.total_qtvenda, 0) > 0 OR COALESCE(p.faturamento, 0) > 0 OR
                     (SELECT COALESCE(SUM(val::numeric), 0) FROM jsonb_each_text(dp.estoque_filial) AS f(key, val) WHERE (%L IS NULL OR array_length(%L::text[], 1) IS NULL OR key = ANY(%L::text[]))) > 0)
                ORDER BY caixas DESC
                LIMIT 1000
            )
            SELECT 
                (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas, ''clientes'', clientes)) FROM chart_agg),
                (SELECT row_to_json(c) FROM kpi_curr c),
                (SELECT row_to_json(p) FROM kpi_prev p),
                (SELECT row_to_json(t) FROM kpi_tri t),
                (SELECT json_agg(pa) FROM prod_agg pa)
        ', 
        v_where_raw_base, v_previous_year, v_current_year, v_previous_year, v_current_year, -- base_data detailed (1 %s, 4 %L)
        v_where_raw_base, v_previous_year, v_current_year, v_previous_year, v_current_year, -- base_data history (1 %s, 4 %L)
        
        v_client_activity_sql,
        v_active_client_cond_slow,
        v_active_client_cond_slow, make_date(v_current_year, 1, 1), make_date(v_current_year + 1, 1, 1), CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM s.dtped) = %L ', v_target_month) ELSE '' END,
        v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND ca.m_idx = %L ', v_target_month - 1) ELSE '' END,
        v_active_client_cond_slow, make_date(v_previous_year, 1, 1), make_date(v_previous_year + 1, 1, 1), CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM s.dtped) = %L ', v_target_month) ELSE '' END,
        v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND ca.m_idx = %L ', v_target_month - 1) ELSE '' END,
        v_tri_start, v_tri_end, -- kpi_tri_raw base query (2 %L)
        v_active_client_cond_slow, v_tri_start, v_tri_end, -- kpi_tri monthly clients subquery (1 %s, 2 %L)

        -- ⚡ QueryTuner: Updated prod_agg to use sargable date boundaries instead of EXTRACT(YEAR), passing v_current_year twice
        v_active_client_cond_slow, v_prod_start_date, v_prod_end_date, -- prod_raw (1 %s, 2 %L)
        v_where_dim_produtos, p_filial, p_filial, p_filial -- prod_agg
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    -- Enrich products_table with trend_estq
    -- ⚡ QueryTuner: Optimized N+1 LATERAL query for 6m sales trend into a pre-aggregated CTE using target_products
    IF v_products_table IS NOT NULL AND json_array_length(v_products_table) > 0 THEN
        WITH target_products AS (
            SELECT p->>'produto' as produto FROM json_array_elements(v_products_table) p
        ),
        sales_6m AS (
            SELECT produto, SUM(qtvenda) as qtvenda_6m
            FROM public.data_detailed
            WHERE dtped >= (v_max_sale_date - interval '6 months')::date AND dtped <= v_max_sale_date AND tipovenda IN ('1', '9')
            AND produto IN (SELECT produto FROM target_products)
            GROUP BY produto
            UNION ALL
            SELECT produto, SUM(qtvenda) as qtvenda_6m
            FROM public.data_history
            WHERE dtped >= (v_max_sale_date - interval '6 months')::date AND dtped <= v_max_sale_date AND tipovenda IN ('1', '9')
            AND produto IN (SELECT produto FROM target_products)
            GROUP BY produto
        ),
        agg_sales_6m AS (
            SELECT produto, SUM(qtvenda_6m) as total_qtvenda_6m FROM sales_6m GROUP BY produto
        )
        SELECT json_agg(
            json_build_object(
                'produto', p->>'produto',
                'descricao', p->>'descricao',
                'caixas', (p->>'caixas')::numeric,
                'faturamento', (p->>'faturamento')::numeric,
                'peso', (p->>'peso')::numeric,
                'clientes', (p->>'clientes')::numeric,
                'ultima_venda', p->>'ultima_venda',
                'estoque', COALESCE(sub.estoque, 0),
                'total_caixas_6m', COALESCE(sub.total_caixas_6m, 0),
                'elapsed_days', COALESCE(sub.elapsed_days, 0),
                'tend_estq', CASE
                    WHEN COALESCE(sub.estoque, 0) = 0 THEN 0
                    WHEN COALESCE(sub.elapsed_days, 0) = 0 THEN 0
                    WHEN COALESCE(sub.total_caixas_6m, 0) = 0 THEN 0
                    ELSE ROUND((COALESCE(sub.estoque, 0) / (sub.total_caixas_6m / sub.elapsed_days::numeric))::numeric, 0)
                END
            )
        )
        INTO v_products_table
        FROM json_array_elements(v_products_table) p
        LEFT JOIN LATERAL (
            SELECT
                (
                    SELECT SUM(val::numeric)
                    FROM jsonb_each_text(dp.estoque_filial) AS f(key, val)
                    WHERE (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR key = ANY(p_filial))
                ) as estoque,
                (v_max_sale_date - GREATEST(dp.dt_cadastro, (v_max_sale_date - interval '6 months')::date) + 1) as elapsed_days,
                ( COALESCE(s6.total_qtvenda_6m, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1) ) as total_caixas_6m
            FROM public.dim_produtos dp
            LEFT JOIN agg_sales_6m s6 ON s6.produto = dp.codigo
            WHERE dp.codigo = (p->>'produto')
        ) sub ON true;
    END IF;

    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json),
        'trend_info', json_build_object(
            'allowed', v_trend_allowed,
            'factor', v_trend_factor,
            'current_month_index', v_curr_month_idx
        )
    );
END;
$function$;

-- Invalidate cached reports on the next dashboard initialization.
CREATE OR REPLACE FUNCTION public.get_data_version()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_last_update timestamp with time zone;
BEGIN
    PERFORM private.evolution_assert_approved();
    SELECT MAX(created_at) INTO v_last_update FROM public.data_summary;
    RETURN COALESCE(v_last_update::text, '1970-01-01 00:00:00+00') || ':boxes-packaging-v2';
END;
$function$;
