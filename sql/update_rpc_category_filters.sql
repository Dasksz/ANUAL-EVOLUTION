
-- Update get_city_view_data to support Category Filter
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
    p_inactive_limit int default 50,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

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
    -- UPDATE: Codes
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;

    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND categoria_produto = ANY(%L) ', p_categoria);
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
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
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
        json_build_object(
            ''cols'', json_build_array(''Código'', ''fantasia'', ''razaoSocial'', ''totalFaturamento'', ''cidade'', ''bairro'', ''rca1''),
            ''rows'', COALESCE(json_agg(json_build_array(pc.codcli, pc.fantasia, pc.razaosocial, pc.total_fat, pc.cidade, pc.bairro, pc.rca1) ORDER BY pc.total_fat DESC), ''[]''::json)
        )
    FROM paginated_clients pc;
    ';

    EXECUTE v_sql INTO v_total_active_count, v_active_clients USING p_limit, p_page;

    -- INACTIVE CLIENTS QUERY
    -- Note: Inactive clients are those in `data_clients` who do NOT appear in `data_summary` given the current filters.
    -- If we filter by Category "X", then "Inactive" means "Did not buy Category X".
    -- This matches the existing logic: `AND NOT EXISTS (SELECT 1 FROM public.data_summary s2 ... WHERE ...)`

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
        json_build_object(
            ''cols'', json_build_array(''Código'', ''fantasia'', ''razaoSocial'', ''cidade'', ''bairro'', ''ultimaCompra'', ''rca1''),
            ''rows'', COALESCE(json_agg(json_build_array(pi.codigo_cliente, pi.fantasia, pi.razaosocial, pi.cidade, pi.bairro, pi.ultimacompra, pi.rca1) ORDER BY pi.ultimacompra DESC NULLS LAST), ''[]''::json)
        )
    FROM paginated_inactive pi;
    ';

    EXECUTE v_sql INTO v_total_inactive_count, v_inactive_clients USING p_inactive_limit, p_inactive_page;

    RETURN json_build_object(
        'active_clients', v_active_clients,
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', v_inactive_clients,
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
END;
$$;


-- Update get_branch_comparison_data to support Category Filter
CREATE OR REPLACE FUNCTION get_branch_comparison_data(
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
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';

    -- 1. Date & Trend Setup
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_target_month := p_mes::int + 1;
    ELSE SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year; END IF;

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

    -- UPDATE: Codes
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND categoria_produto = ANY(%L) ', p_categoria);
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
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao
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
                ''peso'', peso,
                ''bonificacao'', bonificacao
            ) ORDER BY mes),
            ''trend_allowed'', $2,
            ''trend_data'', CASE WHEN $2 THEN
                 (SELECT json_build_object(''month_index'', mes - 1, ''faturamento'', faturamento * $3, ''peso'', peso * $3, ''bonificacao'', bonificacao * $3)
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


-- Update get_boxes_dashboard_data to support Category Filter
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
    v_ref_date date;
    v_tri_start date;
    v_tri_end date;

    v_where_summary text := ' WHERE 1=1 ';
    v_where_raw text := ' WHERE 1=1 ';

    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_use_cache boolean := true;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

    -- 1. Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
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

    -- 2. Build FILTERS
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_use_cache := false;
        v_where_raw := v_where_raw || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND filial = ANY(%L) ', p_filial);
        v_where_summary := v_where_summary || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_summary := v_where_summary || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    -- Map Name to Code
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
         v_where_summary := v_where_summary || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
         v_where_summary := v_where_summary || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        v_where_summary := v_where_summary || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;

    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND categoria_produto = ANY(%L) ', p_categoria);
        v_where_raw := v_where_raw || format(' AND dp.categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND codfor = ANY(%L) ', p_fornecedor);

        -- Raw Logic (Complex OR/AND for mapped codes)
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' AND dp.descricao NOT ILIKE ''%TODDY %'' AND dp.descricao NOT ILIKE ''%QUAKER%'' AND dp.descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;
            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('s.codfor = ANY(%L)', v_simple_codes));
            END IF;
            IF array_length(v_conditions, 1) > 0 THEN
                v_where_raw := v_where_raw || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
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
           v_where_summary := v_where_summary || ' AND (' || v_rede_condition || ') ';
           v_where_raw := v_where_raw || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Execute Queries

    IF v_use_cache THEN
        -- FAST PATH (Uses data_summary for totals)
        EXECUTE format('
            WITH
            chart_agg AS (
                SELECT
                    mes - 1 as m_idx,
                    ano as yr,
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano IN (%L, %L)
                GROUP BY 1, 2
            ),
            kpi_curr AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano = %L %s
            ),
            kpi_prev AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano = %L %s
            ),
            kpi_tri AS (
                SELECT
                    SUM(vlvenda) / 3 as fat,
                    SUM(peso) / 3 as peso,
                    SUM(COALESCE(caixas, 0)) / 3 as caixas
                FROM public.data_summary
                %s AND make_date(ano, mes, 1) >= %L AND make_date(ano, mes, 1) <= %L
            ),
            -- Products Table (Updated to JOIN dim_produtos)
            prod_base AS (
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao, s.dtped
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
                UNION ALL
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao, s.dtped
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
            ),
            prod_agg AS (
                SELECT
                    produto,
                    MAX(descricao) as descricao,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                    SUM(vlvenda) as faturamento,
                    SUM(totpesoliq) as peso,
                    MAX(dtped) as ultima_venda
                FROM prod_base
                GROUP BY 1
                ORDER BY caixas DESC
                LIMIT 50
            )
            SELECT
                (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas)) FROM chart_agg),
                (SELECT row_to_json(c) FROM kpi_curr c),
                (SELECT row_to_json(p) FROM kpi_prev p),
                (SELECT row_to_json(t) FROM kpi_tri t),
                (SELECT json_agg(pa) FROM prod_agg pa)
        ',
        v_where_summary, v_current_year, v_previous_year, -- Chart
        v_where_summary, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Curr
        v_where_summary, v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Prev
        v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), -- KPI Tri
        v_where_raw, v_current_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- Prod
        v_where_raw, v_current_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END  -- Prod
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    ELSE
        -- SLOW PATH (Full Raw Data with dim_produtos join)
        EXECUTE format('
            WITH base_data AS (
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
                UNION ALL
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
            ),
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
            kpi_curr AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
            ),
            kpi_prev AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
            ),
            kpi_tri AS (
                SELECT
                    SUM(vlvenda) / 3 as fat,
                    SUM(totpesoliq) / 3 as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) / 3 as caixas
                FROM base_data
                WHERE dtped >= %L AND dtped <= %L
            ),
            prod_agg AS (
                SELECT
                    produto,
                    MAX(descricao) as descricao,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                    SUM(vlvenda) as faturamento,
                    SUM(totpesoliq) as peso,
                    MAX(dtped) as ultima_venda
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
                GROUP BY 1
                ORDER BY caixas DESC
                LIMIT 50
            )
            SELECT
                (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas)) FROM chart_agg),
                (SELECT row_to_json(c) FROM kpi_curr c),
                (SELECT row_to_json(p) FROM kpi_prev p),
                (SELECT row_to_json(t) FROM kpi_tri t),
                (SELECT json_agg(pa) FROM prod_agg pa)
        ',
        v_where_raw, v_previous_year,
        v_where_raw, v_previous_year,
        v_current_year, v_previous_year,
        v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END,
        v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END,
        v_tri_start, v_tri_end,
        v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;
    END IF;

    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json)
    );
END;
$$;


-- Update get_comparison_view_data to support Category Filter
CREATE OR REPLACE FUNCTION get_comparison_view_data(
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
    -- Date Ranges
    v_ref_date date;
    v_start_target timestamp with time zone;
    v_end_target timestamp with time zone;
    v_start_quarter timestamp with time zone;
    v_end_quarter timestamp with time zone;

    -- Filter Clause
    v_where text := ' WHERE 1=1 ';
    v_where_rede text := '';

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_month_start date;
    v_month_end date;
    v_work_days_passed int;
    v_work_days_total int;

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

    SET LOCAL statement_timeout = '120s'; -- Explicitly increased for heavy agg

    -- 1. Date Logic
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        IF p_mes IS NOT NULL AND p_mes != '' THEN
            v_ref_date := make_date(p_ano::int, p_mes::int + 1, 15);
            v_end_target := (make_date(p_ano::int, p_mes::int + 1, 1) + interval '1 month' - interval '1 second');
        ELSE
            IF p_ano::int = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
                v_ref_date := CURRENT_DATE;
            ELSE
                v_ref_date := make_date(p_ano::int, 12, 31);
            END IF;
            v_end_target := (v_ref_date + interval '1 day' - interval '1 second');
        END IF;
    ELSE
        SELECT MAX(dtped) INTO v_end_target FROM public.data_detailed;
        IF v_end_target IS NULL THEN v_end_target := now(); END IF;
        v_ref_date := v_end_target::date;
    END IF;

    v_start_target := date_trunc('month', v_ref_date);
    v_end_target := (v_start_target + interval '1 month' - interval '1 second');

    v_end_quarter := v_start_target - interval '1 second';
    v_start_quarter := date_trunc('month', v_end_quarter - interval '2 months');

    -- Trend Calculation
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (EXTRACT(YEAR FROM v_end_target) = EXTRACT(YEAR FROM v_max_sale_date) AND EXTRACT(MONTH FROM v_end_target) = EXTRACT(MONTH FROM v_max_sale_date));

    IF v_trend_allowed THEN
        v_month_start := date_trunc('month', v_max_sale_date);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        END IF;
    END IF;

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

    -- FORNECEDOR LOGIC (Modified to check joined dim_produtos for description)
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' AND dp.descricao NOT ILIKE ''%TODDY %'' AND dp.descricao NOT ILIKE ''%QUAKER%'' AND dp.descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;

            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('s.codfor = ANY(%L)', v_simple_codes));
            END IF;

            IF array_length(v_conditions, 1) > 0 THEN
                v_where := v_where || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where := v_where || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND dp.categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- REDE Logic
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

    -- 3. Aggregation Queries

    EXECUTE format('
        WITH target_sales AS (
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_detailed s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
            UNION ALL
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_history s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
        ),
        history_sales AS (
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_detailed s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
            UNION ALL
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_history s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
        ),
        -- Current Aggregates
        curr_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM target_sales GROUP BY 1
        ),
        curr_prod_agg AS (
            SELECT s.codcli, s.produto, MAX(dp.mix_marca) as mix_marca, MAX(dp.mix_categoria) as mix_cat, MAX(s.codfor) as codfor, SUM(s.vlvenda) as prod_val
            FROM target_sales s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            GROUP BY 1, 2
        ),
        curr_mix_base AS (
            SELECT
                codcli,
                SUM(prod_val) as total_val,
                COUNT(CASE WHEN codfor IN (''707'', ''708'') AND prod_val >= 1 THEN 1 END) as pepsico_skus,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''CHEETOS'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''DORITOS'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''FANDANGOS'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''RUFFLES'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TORCIDA'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDYNHO'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDY'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''QUAKER'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''KEROCOCO'' THEN 1 ELSE 0 END) as has_kerococo
            FROM curr_prod_agg
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
        hist_prod_agg AS (
            SELECT date_trunc(''month'', dtped) as m_date, s.codcli, s.produto, MAX(dp.mix_marca) as mix_marca, MAX(dp.mix_categoria) as mix_cat, MAX(s.codfor) as codfor, SUM(s.vlvenda) as prod_val
            FROM history_sales s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            GROUP BY 1, 2, 3
        ),
        hist_monthly_mix AS (
            SELECT
                m_date,
                codcli,
                SUM(prod_val) as total_val,
                COUNT(CASE WHEN codfor IN (''707'', ''708'') AND prod_val >= 1 THEN 1 END) as pepsico_skus,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''CHEETOS'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''DORITOS'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''FANDANGOS'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''RUFFLES'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TORCIDA'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDYNHO'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDY'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''QUAKER'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''KEROCOCO'' THEN 1 ELSE 0 END) as has_kerococo
            FROM hist_prod_agg
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
        'trend_info', json_build_object('allowed', v_trend_allowed, 'factor', v_trend_factor),
        'debug_range', json_build_object('start', v_start_target, 'end', v_end_target, 'h_start', v_start_quarter, 'h_end', v_end_quarter)
    );
END;
$$;
