-- This script patches the `get_innovations_data` to support the new YoY and 12-month average comparisons

DROP FUNCTION IF EXISTS get_innovations_data(text[], text[], text[], text[], text[], text[], text);
DROP FUNCTION IF EXISTS get_innovations_data(text[], text[], text[], text[], text[], text[], text, text, text);

CREATE OR REPLACE FUNCTION get_innovations_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_rede text[] default null,
    p_tipovenda text[] default null,
    p_categoria_inovacao text default null,
    p_ano text default null,
    p_mes text default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $BODY$
DECLARE
    v_result json;
    v_where_base text := ' WHERE 1=1 ';
    v_sql text;

    v_last_sale_date date;

    v_target_date date;
    v_month_curr text; -- Formatted YYYY-MM
    v_month_prev_year text; -- Formatted YYYY-MM
    v_month_12m_start text; -- Formatted YYYY-MM
    v_month_12m_end text; -- Formatted YYYY-MM

    v_where_inov text := ' 1=1 ';
    v_filial_cities text[];
BEGIN
    -- 1. Determine the target date based on filters and latest sale
    SELECT MAX(dtped) INTO v_last_sale_date FROM data_detailed;

    IF v_last_sale_date IS NULL THEN
        RETURN json_build_object('active_clients', 0, 'categories', '[]'::json, 'products', '[]'::json);
    END IF;

    -- Se tem ano filtrado
    IF p_ano IS NOT NULL AND p_ano != 'todos' THEN
        IF p_mes IS NOT NULL AND p_mes != '' THEN
            -- Se tem ano e mês
            v_target_date := to_date(p_ano || '-' || p_mes || '-01', 'YYYY-MM-DD');
            -- Se for o mês atual ou futuro comparado à ultima venda, ajusta pra não passar do máximo disponível
            IF v_target_date > v_last_sale_date THEN
               -- Aqui deixamos como está, vai mostrar 0 se for no futuro, ou o usuário sabe o que tá fazendo
               NULL;
            END IF;
        ELSE
            -- Se tem só ano, pega o mês mais recente daquele ano
            -- ex: Se v_last_sale_date é 2026-03-03, e p_ano é 2026 -> v_target_date = 2026-03-03
            -- Se p_ano é 2025 -> v_target_date = 2025-12-31
            IF p_ano = to_char(v_last_sale_date, 'YYYY') THEN
                v_target_date := v_last_sale_date;
            ELSE
                v_target_date := to_date(p_ano || '-12-31', 'YYYY-MM-DD');
            END IF;
        END IF;
    ELSE
        -- Sem filtro de ano, usa o latest
        v_target_date := v_last_sale_date;
    END IF;

    -- Format YYYY-MM for exact match filtering
    v_month_curr := to_char(v_target_date, 'YYYY-MM');
    v_month_prev_year := to_char(v_target_date - interval '1 year', 'YYYY-MM');

    -- 12 month average calculation period (last 12 months excluding the current one)
    v_month_12m_end := to_char(v_target_date - interval '1 month', 'YYYY-MM');
    v_month_12m_start := to_char(v_target_date - interval '12 months', 'YYYY-MM');

    -- 2. Build Where Clauses for Clients
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            SELECT array_agg(DISTINCT cidade) INTO v_filial_cities
            FROM public.config_city_branches
            WHERE filial = ANY(p_filial);

            IF v_filial_cities IS NOT NULL THEN
                v_where_base := v_where_base || ' AND c.cidade = ANY(ARRAY[''' || array_to_string(v_filial_cities, ''',''') || ''']) ';
            ELSE
                v_where_base := v_where_base || ' AND 1=0 ';
            END IF;
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || ' AND c.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || ' AND c.rca1 = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || ''']) ';
    END IF;

    -- Redes
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF 'com_ramo' = ANY(p_rede) AND 'sem_ramo' = ANY(p_rede) THEN
            -- Do nothing, include all
        ELSIF 'com_ramo' = ANY(p_rede) THEN
            v_where_base := v_where_base || ' AND c.ramo IS NOT NULL AND c.ramo != '''' ';
        ELSIF 'sem_ramo' = ANY(p_rede) THEN
            v_where_base := v_where_base || ' AND (c.ramo IS NULL OR c.ramo = '''') ';
        ELSE
            v_where_base := v_where_base || ' AND c.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
    END IF;

    -- Categoria Inovação Filter
    IF p_categoria_inovacao IS NOT NULL AND p_categoria_inovacao != '' THEN
        v_where_inov := ' i.inovacoes = ' || quote_literal(p_categoria_inovacao) || ' ';
    END IF;

    -- 3. Dynamic Query Execution
    v_sql := '
    WITH active_clients AS (
        SELECT DISTINCT d.codcli
        FROM (
            SELECT codcli FROM data_detailed WHERE to_char(dtped, ''YYYY-MM'') = ''' || v_month_curr || '''
            UNION ALL
            SELECT codcli FROM data_history WHERE to_char(dtped, ''YYYY-MM'') = ''' || v_month_curr || '''
                                               OR to_char(dtped, ''YYYY-MM'') = ''' || v_month_prev_year || '''
                                               OR (to_char(dtped, ''YYYY-MM'') BETWEEN ''' || v_month_12m_start || ''' AND ''' || v_month_12m_end || ''')
        ) d
        JOIN data_clients c ON c.codigo_cliente = d.codcli
        ' || v_where_base || '
    ),
    innovation_sales AS (
        SELECT
            i.inovacoes AS category_name,
            i.codigo AS product_code,
            p.descricao AS product_name,
            CASE
                WHEN to_char(d.dtped, ''YYYY-MM'') = ''' || v_month_curr || ''' THEN ''current''
                WHEN to_char(d.dtped, ''YYYY-MM'') = ''' || v_month_prev_year || ''' THEN ''prev_year''
                WHEN to_char(d.dtped, ''YYYY-MM'') BETWEEN ''' || v_month_12m_start || ''' AND ''' || v_month_12m_end || ''' THEN ''avg_12m''
            END AS period,
            to_char(d.dtped, ''YYYY-MM'') AS period_month,
            d.codcli
        FROM (
            SELECT codcli, produto, dtped FROM data_detailed WHERE to_char(dtped, ''YYYY-MM'') = ''' || v_month_curr || '''
            UNION ALL
            SELECT codcli, produto, dtped FROM data_history WHERE to_char(dtped, ''YYYY-MM'') = ''' || v_month_curr || '''
                                                                 OR to_char(dtped, ''YYYY-MM'') = ''' || v_month_prev_year || '''
                                                                 OR (to_char(dtped, ''YYYY-MM'') BETWEEN ''' || v_month_12m_start || ''' AND ''' || v_month_12m_end || ''')
        ) d
        JOIN data_innovations i ON d.produto = i.codigo
        JOIN dim_produtos p ON p.codigo = i.codigo
        JOIN active_clients ac ON ac.codcli = d.codcli
        WHERE ' || v_where_inov || '
    ),
    pos_by_period AS (
        SELECT
            category_name,
            product_code,
            product_name,
            period,
            COUNT(DISTINCT codcli) AS pos_count
        FROM innovation_sales
        WHERE period IN (''current'', ''prev_year'')
        GROUP BY 1, 2, 3, 4
    ),
    pos_12m AS (
        SELECT
            category_name,
            product_code,
            product_name,
            COUNT(DISTINCT codcli) / 12.0 AS pos_count -- Average over 12 months
        FROM innovation_sales
        WHERE period = ''avg_12m''
        GROUP BY 1, 2, 3, period_month
    ),
    pos_12m_avg AS (
        SELECT
            category_name,
            product_code,
            product_name,
            SUM(pos_count) AS pos_avg -- Sum of (monthly pos / 12)
        FROM pos_12m
        GROUP BY 1, 2, 3
    ),
    aggregated AS (
        SELECT
            COALESCE(pbp.category_name, p12.category_name) AS category_name,
            COALESCE(pbp.product_code, p12.product_code) AS product_code,
            COALESCE(pbp.product_name, p12.product_name) AS product_name,
            COALESCE(MAX(CASE WHEN pbp.period = ''current'' THEN pbp.pos_count END), 0) AS pos_current,
            COALESCE(MAX(CASE WHEN pbp.period = ''prev_year'' THEN pbp.pos_count END), 0) AS pos_prev_year,
            COALESCE(MAX(p12.pos_avg), 0) AS pos_avg_12m
        FROM pos_by_period pbp
        FULL OUTER JOIN pos_12m_avg p12 ON pbp.product_code = p12.product_code
        GROUP BY 1, 2, 3
    )
    SELECT json_build_object(
        ''active_clients'', (SELECT COUNT(*) FROM active_clients),
        ''categories'', (
            SELECT COALESCE(json_agg(cat_agg), ''[]''::json)
            FROM (
                SELECT
                    json_build_object(
                        ''name'', category_name,
                        ''pos_current'', SUM(pos_current),
                        ''pos_prev_year'', SUM(pos_prev_year),
                        ''pos_avg_12m'', SUM(pos_avg_12m),
                        ''products_count'', COUNT(product_code)
                    ) as cat_agg
                FROM aggregated
                GROUP BY category_name
            ) sub
        ),
        ''products'', (
            SELECT COALESCE(json_agg(row_to_json(aggregated)), ''[]''::json) FROM aggregated
        )
    );
    ';

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$BODY$;