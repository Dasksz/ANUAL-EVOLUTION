
-- Update get_boxes_dashboard_data to return Chart (Full Year), KPI Current, KPI Previous (Same Period), and KPI Tri Avg (Prior Quarter)

CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null
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
    v_ref_date date;
    v_tri_start date;
    v_tri_end date;

    v_where_common text := ' WHERE 1=1 ';

    -- Outputs
    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    -- Helpers
    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '64MB';

    -- 1. Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    -- Determine Reference Date for Tri Logic
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        -- Target is 1st of selected month. Tri is previous 3 months.
        v_ref_date := make_date(v_current_year, v_target_month, 1);
    ELSE
        -- No month selected.
        IF v_current_year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
            -- Past year -> Dec is reference (so Tri is Sep/Oct/Nov?)
            -- User: "média do trimestre anterior ao mês mais recente"
            -- If year is full, most recent is Dec. Tri anterior to Dec is Sep/Oct/Nov.
            -- v_ref_date = 1st Dec.
            v_ref_date := make_date(v_current_year, 12, 1);
        ELSE
             -- Current Year -> Current Month.
             v_ref_date := date_trunc('month', CURRENT_DATE)::date;
        END IF;
    END IF;

    -- Tri Calculation: 3 months before v_ref_date.
    -- e.g. Ref = May 1st. Tri = Feb 1st to Apr 30th.
    v_tri_end := (v_ref_date - interval '1 day')::date;
    v_tri_start := (v_ref_date - interval '3 months')::date;


    -- 2. Build COMMON WHERE (Exclude Time filters)
    -- Applied to data_detailed/history directly

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         -- Optimization: Join is better but for dynamic string building:
         v_where_common := v_where_common || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_common := v_where_common || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao NOT ILIKE ''%TODDYNHO%'' AND descricao NOT ILIKE ''%TODDY %'' AND descricao NOT ILIKE ''%QUAKER%'' AND descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;
            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('codfor = ANY(%L)', v_simple_codes));
            END IF;
            IF array_length(v_conditions, 1) > 0 THEN
                v_where_common := v_where_common || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
    END IF;

    -- REDE Logic (Exists check on Clients)
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
           v_where_common := v_where_common || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Execute Queries

    EXECUTE format('
        WITH base_data AS (
            SELECT dtped, vlvenda, totpesoliq, qtvenda_embalagem_master, produto, descricao, filial
            FROM public.data_detailed s
            %s
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, qtvenda_embalagem_master, produto, descricao, filial
            FROM public.data_history s
            %s
        ),
        -- Chart Data (Current vs Previous Year, Full 12 Months)
        chart_agg AS (
            SELECT
                EXTRACT(MONTH FROM dtped)::int - 1 as m_idx,
                EXTRACT(YEAR FROM dtped)::int as yr,
                SUM(vlvenda) as fat,
                SUM(totpesoliq) as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) IN (%L, %L)
            GROUP BY 1, 2
        ),
        -- KPI Current (Selected Year + Optional Month)
        kpi_curr AS (
            SELECT
                SUM(vlvenda) as fat,
                SUM(totpesoliq) as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter
        ),
        -- KPI Previous (Previous Year + Optional Month)
        kpi_prev AS (
            SELECT
                SUM(vlvenda) as fat,
                SUM(totpesoliq) as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter (Same month index)
        ),
        -- KPI Tri Avg (Specific Date Range)
        kpi_tri AS (
            SELECT
                SUM(vlvenda) / 3 as fat,
                SUM(totpesoliq) / 3 as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) / 3 as caixas
            FROM base_data
            WHERE dtped >= %L AND dtped <= %L
        ),
        -- Products Table (Selected Year + Optional Month)
        prod_agg AS (
            SELECT
                produto,
                MAX(descricao) as descricao,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                SUM(vlvenda) as faturamento,
                SUM(totpesoliq) as peso
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter
            GROUP BY 1
            ORDER BY caixas DESC
            LIMIT 50
        )
        SELECT
            (SELECT json_agg(json_build_object(
                ''month_index'', m_idx,
                ''year'', yr,
                ''faturamento'', fat,
                ''peso'', peso,
                ''caixas'', caixas
             )) FROM chart_agg),

            (SELECT row_to_json(c) FROM kpi_curr c),
            (SELECT row_to_json(p) FROM kpi_prev p),
            (SELECT row_to_json(t) FROM kpi_tri t),
            (SELECT json_agg(pa) FROM prod_agg pa)
    ',
    v_where_common, v_where_common, -- CTE
    v_current_year, v_previous_year, -- Chart
    v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- KPI Curr
    v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- KPI Prev
    v_tri_start, v_tri_end, -- KPI Tri
    v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END -- Prod Table
    )
    INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    -- Transform Chart Data into friendly structure (group by month)
    -- Or let JS do it. JS expects array of months.
    -- Let's stick to raw rows and map in JS, or format nicely here.
    -- Better format here: Array of 12 items, each with current and previous.

    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json),
        'debug_tri', json_build_object('start', v_tri_start, 'end', v_tri_end)
    );
END;
$$;
