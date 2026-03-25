CREATE OR REPLACE FUNCTION get_mix_salty_foods_data(
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
    v_where_chart text := ' WHERE tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1 ';
    v_sql text;
    v_result json;
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary_frequency;
    ELSE
        v_current_year := p_ano::int;
    END IF;

    -- For the chart we always want the full current year to show the trend
    v_where_chart := v_where_chart || ' AND ano = ' || v_current_year || ' ';

    -- 2. Build Where Clauses
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF ('com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede)) AND ('sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede)) THEN
            -- Do nothing
        ELSIF 'com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede) THEN
            v_where_chart := v_where_chart || ' AND rede IS NOT NULL AND rede != '''' ';
        ELSIF 'sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede) THEN
            v_where_chart := v_where_chart || ' AND (rede IS NULL OR rede = '''') ';
        ELSE
            v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    -- Dynamic Query
    -- To find if a client positivou Salty: needs ALL 5 categories
    -- To find if a client positivou Foods: needs ALL 4 categories (either TODDY or TODDY )
    v_sql := '
    WITH monthly_client_categories AS (
        SELECT
            ano,
            mes,
            codcli,
            jsonb_agg(categorias) as all_categorias_month
        FROM public.data_summary_frequency s
        ' || v_where_chart || '
        GROUP BY ano, mes, codcli
    ),
    client_pos_flags AS (
        SELECT
            ano,
            mes,
            codcli,
            (
                all_categorias_month::text LIKE ''%"CHEETOS"%'' AND
                all_categorias_month::text LIKE ''%"DORITOS"%'' AND
                all_categorias_month::text LIKE ''%"FANDANGOS"%'' AND
                all_categorias_month::text LIKE ''%"RUFFLES"%'' AND
                all_categorias_month::text LIKE ''%"TORCIDA"%''
            ) as is_salty,
            (
                all_categorias_month::text LIKE ''%"TODDYNHO"%'' AND
                (all_categorias_month::text LIKE ''%"TODDY"%'' OR all_categorias_month::text LIKE ''%"TODDY "%'') AND
                all_categorias_month::text LIKE ''%"QUAKER"%'' AND
                all_categorias_month::text LIKE ''%"KEROCOCO"%''
            ) as is_foods
        FROM monthly_client_categories
    ),
    chart_data AS (
        SELECT
            ano,
            mes,
            COUNT(DISTINCT CASE WHEN is_salty THEN codcli END) as total_salty,
            COUNT(DISTINCT CASE WHEN is_foods THEN codcli END) as total_foods,
            COUNT(DISTINCT CASE WHEN is_salty AND is_foods THEN codcli END) as total_ambas
        FROM client_pos_flags
        GROUP BY ano, mes
        ORDER BY ano, mes
    )
    SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data;
    ';

    EXECUTE v_sql INTO v_result;

    RETURN json_build_object(
        'chart_data', v_result,
        'current_year', v_current_year
    );
END;
$$;
