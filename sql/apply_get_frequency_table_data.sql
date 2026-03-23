CREATE OR REPLACE FUNCTION public.get_frequency_table_data(
    p_ano text DEFAULT NULL,
    p_mes text DEFAULT NULL,
    p_filial text[] DEFAULT NULL::text[],
    p_cidade text[] DEFAULT NULL::text[],
    p_vendedor text[] DEFAULT NULL::text[],
    p_supervisor text[] DEFAULT NULL::text[],
    p_fornecedor text[] DEFAULT NULL::text[],
    p_produto text[] DEFAULT NULL::text[],
    p_tipovenda text[] DEFAULT NULL::text[],
    p_rede text[] DEFAULT NULL::text[],
    p_categoria text[] DEFAULT NULL::text[]
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_where_base text := ' WHERE 1=1 ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';

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

    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int;
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' AND s.mes = ' || v_target_month || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' AND s.mes = ' || v_target_month || ' ';
    ELSE
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' ';
    END IF;

    -- 2. Applying Filters
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_clients := v_where_clients || ' AND cb.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_clients := v_where_clients || ' AND dc.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = s.codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = s.codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_clients := v_where_clients || ' AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.dim_supervisores ds WHERE ds.codigo = s.codsupervisor AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.dim_supervisores ds WHERE ds.codigo = s.codsupervisor AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';

        v_where_clients := v_where_clients || ' AND EXISTS (
            SELECT 1 FROM public.data_summary_frequency sf
            JOIN public.dim_supervisores ds ON sf.codsupervisor = ds.codigo
            WHERE sf.codcli = dc.codigo_cliente AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])
        ) ';
        v_where_chart := v_where_chart || ' AND EXISTS (SELECT 1 FROM public.dim_supervisores ds WHERE ds.codigo = codsupervisor AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF p_fornecedor[1] = 'PEPSICO' THEN
            v_where_base := v_where_base || ' AND s.codfor IN (''707'', ''708'', ''752'') ';
            v_where_base_prev := v_where_base_prev || ' AND s.codfor IN (''707'', ''708'', ''752'') ';
            v_where_chart := v_where_chart || ' AND codfor IN (''707'', ''708'', ''752'') ';
        ELSE
            v_where_base := v_where_base || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dc.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    -- Dynamic Query
    v_sql := '
    WITH base_clients AS (
        SELECT
            dc.codigo_cliente as codcli,
            COALESCE(cb.filial, ''SEM FILIAL'') as filial,
            COALESCE(dc.cidade, ''SEM CIDADE'') as cidade,
            COALESCE(dv.nome, ''SEM VENDEDOR'') as vendedor
        FROM public.data_clients dc
        LEFT JOIN public.config_city_branches cb USING (cidade)
        LEFT JOIN public.dim_vendedores dv ON dc.rca1 = dv.codigo
        ' || v_where_clients || '
    ),
    current_data AS (
        SELECT
            s.filial,
            s.cidade,
            s.codusur,
            s.mes,
            s.codcli,
            s.pedido,
            s.tipovenda,
            s.vlvenda,
            s.peso,
            s.produtos
        FROM public.data_summary_frequency s
        ' || v_where_base || '
    ),
    previous_data AS (
        SELECT
            GROUPING(s.filial) as grp_filial,
            GROUPING(s.cidade) as grp_cidade,
            GROUPING(s.codusur) as grp_vendedor,
            COALESCE(s.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(s.cidade, ''TOTAL_CIDADE'') as cidade,
            s.codusur as vendedor_cod,
            SUM(s.vlvenda) as faturamento_prev
        FROM public.data_summary_frequency s
        ' || v_where_base_prev || ' AND s.tipovenda NOT IN (''5'', ''11'')
        GROUP BY ROLLUP(s.filial, s.cidade, s.codusur)
    ),
    client_base AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(vendedor) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            COALESCE(vendedor, ''TOTAL_VENDEDOR'') as vendedor,
            COUNT(DISTINCT codcli) as base_total
        FROM base_clients
        GROUP BY ROLLUP(filial, cidade, vendedor)
    ),
    current_skus AS (
        SELECT filial, cidade, codusur, codcli, jsonb_array_elements_text(produtos) as sku
        FROM current_data
        WHERE tipovenda NOT IN (''5'', ''11'')
    ),
    pre_aggregated_skus AS (
        SELECT
            filial, cidade, codusur,
            COUNT(DISTINCT codcli || ''-'' || sku) as dist_skus
        FROM current_skus
        GROUP BY filial, cidade, codusur
    ),
    aggregated_curr AS (
        SELECT
            GROUPING(c.filial) as grp_filial,
            GROUPING(c.cidade) as grp_cidade,
            GROUPING(c.codusur) as grp_vendedor,
            COALESCE(c.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(c.cidade, ''TOTAL_CIDADE'') as cidade,
            c.codusur as vendedor_cod,
            SUM(c.peso) as tons,
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.vlvenda ELSE 0 END) as faturamento,
            COUNT(DISTINCT CASE WHEN c.vlvenda >= 1 AND c.tipovenda NOT IN (''5'', ''11'') THEN c.codcli END) as positivacao,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END) as total_pedidos,
            COUNT(DISTINCT c.mes) as q_meses
        FROM current_data c
        GROUP BY ROLLUP(c.filial, c.cidade, c.codusur)
    ),
    aggregated_skus AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            SUM(dist_skus) as sum_skus
        FROM pre_aggregated_skus
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),
    final_tree AS (
        SELECT
            ac.grp_filial,
            ac.grp_cidade,
            ac.grp_vendedor,
            ac.filial,
            ac.cidade,
            COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1),
                CASE WHEN ac.grp_vendedor = 1 THEN ''TOTAL_VENDEDOR'' ELSE ''SEM VENDEDOR'' END
            ) as vendedor,
            ac.tons,
            ac.faturamento,
            COALESCE(pd.faturamento_prev, 0) as faturamento_prev,
            ac.positivacao,
            COALESCE(ask.sum_skus, 0)::numeric as sum_skus,
            ac.total_pedidos::numeric as total_pedidos,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_curr ac
        LEFT JOIN previous_data pd ON ac.grp_filial = pd.grp_filial
                                  AND ac.grp_cidade = pd.grp_cidade
                                  AND ac.grp_vendedor = pd.grp_vendedor
                                  AND ac.filial = pd.filial
                                  AND ac.cidade = pd.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM pd.vendedor_cod
        LEFT JOIN aggregated_skus ask ON ac.grp_filial = ask.grp_filial
                                  AND ac.grp_cidade = ask.grp_cidade
                                  AND ac.grp_vendedor = ask.grp_vendedor
                                  AND ac.filial = ask.filial
                                  AND ac.cidade = ask.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM ask.vendedor_cod
        LEFT JOIN client_base cb ON ac.grp_filial = cb.grp_filial
                                AND ac.grp_cidade = cb.grp_cidade
                                AND ac.grp_vendedor = cb.grp_vendedor
                                AND ac.filial = cb.filial
                                AND ac.cidade = cb.cidade
                                AND COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1),
                                    CASE WHEN ac.grp_vendedor = 1 THEN ''TOTAL_VENDEDOR'' ELSE ''SEM VENDEDOR'' END) = cb.vendedor
    ),
    chart_data AS (
        SELECT
            ano,
            mes,
            COUNT(DISTINCT CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN pedido END) as total_pedidos,
            COUNT(DISTINCT CASE WHEN vlvenda >= 1 AND tipovenda NOT IN (''5'', ''11'') THEN codcli END) as total_clientes
        FROM public.data_summary_frequency s
        ' || v_where_chart || '
        GROUP BY 1, 2
    )
    SELECT json_build_object(
        ''tree_data'', (SELECT COALESCE(json_agg(row_to_json(final_tree)), ''[]''::json) FROM final_tree),
        ''chart_data'', (SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data),
        ''current_year'', ' || v_current_year || ',
        ''previous_year'', ' || v_previous_year || ',
        ''global_base_total'', (SELECT COUNT(DISTINCT codcli) FROM base_clients)
    );
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;
