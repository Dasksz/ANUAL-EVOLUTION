-- Function migration to fix the 'p_rede' parameter array logic
-- Handles BOTH "com_ramo" (C/ REDE) and "sem_ramo" (S/ REDE) tags directly

CREATE OR REPLACE FUNCTION public.get_frequency_table_data(
    p_filial text[] DEFAULT NULL::text[],
    p_cidade text[] DEFAULT NULL::text[],
    p_supervisor text[] DEFAULT NULL::text[],
    p_vendedor text[] DEFAULT NULL::text[],
    p_fornecedor text[] DEFAULT NULL::text[],
    p_ano text DEFAULT NULL::text,
    p_mes text DEFAULT NULL::text,
    p_tipovenda text[] DEFAULT NULL::text[],
    p_rede text[] DEFAULT NULL::text[],
    p_produto text[] DEFAULT NULL::text[],
    p_categoria text[] DEFAULT NULL::text[]
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';

    v_sql text;
    v_result json;
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';
    SET search_path = public;

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

    v_where_chart := v_where_chart || ' AND ano IN (' || v_previous_year || ', ' || v_current_year || ') ';

    -- 2. Build Where Clauses
    -- We apply regional filters (filial, cidade, vendedor) directly to v_where_base, v_where_base_prev, and v_where_clients
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_clients := v_where_clients || ' AND cidade IN (SELECT cidade FROM public.config_city_branches WHERE filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || '''])) ';
            v_where_base := v_where_base || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dc.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND EXISTS (SELECT 1 FROM public.data_summary_frequency sf WHERE sf.codcli = dc.codigo_cliente AND sf.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || ''']))) ';
        v_where_chart := v_where_chart || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base := v_where_base || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base := v_where_base || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_base := v_where_base || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
        END IF;
    END IF;

    -- Redes Filtering Logic matching Innovations
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF ('com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede)) AND ('sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede)) THEN
            -- Do nothing, both selected essentially means all
        ELSIF 'com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND dc.ramo IS NOT NULL AND dc.ramo != '''' ';
            v_where_chart := v_where_chart || ' AND rede IS NOT NULL AND rede != '''' ';
            v_where_base := v_where_base || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
        ELSIF 'sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND (dc.ramo IS NULL OR dc.ramo = '''') ';
            v_where_chart := v_where_chart || ' AND (rede IS NULL OR rede = '''') ';
            v_where_base := v_where_base || ' AND (s.rede IS NULL OR s.rede = '''') ';
            v_where_base_prev := v_where_base_prev || ' AND (s.rede IS NULL OR s.rede = '''') ';
        ELSE
            -- Treat as explicit array values if not our magic tags
            v_where_clients := v_where_clients || ' AND dc.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base := v_where_base || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
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

    monthly_freq AS (
        SELECT
            c.filial,
            c.cidade,
            c.codusur,
            c.mes,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END)::numeric as month_pedidos,
            COUNT(DISTINCT CASE WHEN c.vlvenda >= 1 AND c.tipovenda NOT IN (''5'', ''11'') THEN c.codcli END)::numeric as month_clientes
        FROM current_data c
        GROUP BY c.filial, c.cidade, c.codusur, c.mes
    ),
    rolled_monthly_freq AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            -- Calculate frequency per month, then average those frequencies across active months
            AVG(CASE WHEN month_clientes > 0 THEN month_pedidos / month_clientes ELSE NULL END) as avg_monthly_freq
        FROM monthly_freq
        GROUP BY ROLLUP(filial, cidade, codusur)
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
            COUNT(DISTINCT CASE WHEN c.vlvenda >= 1 AND c.tipovenda NOT IN (''5'', ''11'') THEN c.codcli::text || ''-'' || c.mes::text END) as positivacao_mensal,
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
            ac.positivacao_mensal,
            COALESCE(ask.sum_skus, 0)::numeric as sum_skus,
            ac.total_pedidos::numeric as total_pedidos,
            ac.q_meses,
            COALESCE(mf.avg_monthly_freq, 0) as avg_monthly_freq,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_curr ac
        LEFT JOIN previous_data pd ON ac.grp_filial = pd.grp_filial
                                  AND ac.grp_cidade = pd.grp_cidade
                                  AND ac.grp_vendedor = pd.grp_vendedor
                                  AND ac.filial = pd.filial
                                  AND ac.cidade = pd.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM pd.vendedor_cod

        LEFT JOIN rolled_monthly_freq mf ON ac.grp_filial = mf.grp_filial
                                  AND ac.grp_cidade = mf.grp_cidade
                                  AND ac.grp_vendedor = mf.grp_vendedor
                                  AND ac.filial = mf.filial
                                  AND ac.cidade = mf.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM mf.vendedor_cod
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
$function$;

-- Update the 12 parameter version as well to ensure fallback works everywhere
CREATE OR REPLACE FUNCTION public.get_frequency_table_data(
    p_diretoria text[] DEFAULT NULL::text[],
    p_gerencia text[] DEFAULT NULL::text[],
    p_filial text[] DEFAULT NULL::text[],
    p_vendedor text[] DEFAULT NULL::text[],
    p_supervisor text[] DEFAULT NULL::text[],
    p_ano text DEFAULT NULL::text,
    p_mes text DEFAULT NULL::text,
    p_fornecedor text[] DEFAULT NULL::text[],
    p_rede text[] DEFAULT NULL::text[],
    p_produto text[] DEFAULT NULL::text[],
    p_categoria text[] DEFAULT NULL::text[],
    p_tipovenda text[] DEFAULT NULL::text[]
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sql text;
    v_result json;
    v_where_base text := 'WHERE 1=1';
    v_where_base_prev text := 'WHERE 1=1';
    v_where_chart text := 'WHERE 1=1';
    v_where_clients text := 'WHERE 1=1';
    v_current_year integer;
    v_previous_year integer;
BEGIN
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    v_previous_year := v_current_year - 1;

    IF p_ano IS NOT NULL AND p_ano <> '' THEN
        v_current_year := p_ano::integer;
        v_previous_year := v_current_year - 1;
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year;
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year;
        v_where_chart := v_where_chart || ' AND (ano = ' || v_current_year || ' OR ano = ' || v_previous_year || ') ';
    ELSE
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year;
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year;
        v_where_chart := v_where_chart || ' AND (ano = ' || v_current_year || ' OR ano = ' || v_previous_year || ') ';
    END IF;

    IF p_mes IS NOT NULL AND p_mes <> '' THEN
        v_where_base := v_where_base || ' AND s.mes <= ' || p_mes;
        v_where_base_prev := v_where_base_prev || ' AND s.mes <= ' || p_mes;
        v_where_chart := v_where_chart || ' AND mes <= ' || p_mes;
    END IF;

    IF p_diretoria IS NOT NULL AND array_length(p_diretoria, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND cb.diretoria = ANY(ARRAY[''' || array_to_string(p_diretoria, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = s.cidade AND cb.diretoria = ANY(ARRAY[''' || array_to_string(p_diretoria, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = s.cidade AND cb.diretoria = ANY(ARRAY[''' || array_to_string(p_diretoria, ''',''') || '''])) ';
        v_where_chart := v_where_chart || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = cidade AND cb.diretoria = ANY(ARRAY[''' || array_to_string(p_diretoria, ''',''') || '''])) ';
    END IF;

    IF p_gerencia IS NOT NULL AND array_length(p_gerencia, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND cb.gerencia = ANY(ARRAY[''' || array_to_string(p_gerencia, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = s.cidade AND cb.gerencia = ANY(ARRAY[''' || array_to_string(p_gerencia, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = s.cidade AND cb.gerencia = ANY(ARRAY[''' || array_to_string(p_gerencia, ''',''') || '''])) ';
        v_where_chart := v_where_chart || ' AND EXISTS (SELECT 1 FROM public.config_city_branches cb WHERE cb.cidade = cidade AND cb.gerencia = ANY(ARRAY[''' || array_to_string(p_gerencia, ''',''') || '''])) ';
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND cb.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = s.codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = s.codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_chart := v_where_chart || ' AND EXISTS (SELECT 1 FROM public.dim_vendedores dv WHERE dv.codigo = codusur AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND EXISTS (
            SELECT 1 FROM public.data_summary_frequency sf
            JOIN public.dim_supervisores ds ON sf.codsupervisor = ds.codigo
            WHERE sf.codcli = dc.codigo_cliente AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])
        ) ';
        v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM public.dim_supervisores ds WHERE ds.codigo = s.codsupervisor AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND EXISTS (SELECT 1 FROM public.dim_supervisores ds WHERE ds.codigo = s.codsupervisor AND ds.nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
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
        IF ('com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede)) AND ('sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede)) THEN
            -- Do nothing, both selected essentially means all
        ELSIF 'com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND dc.ramo IS NOT NULL AND dc.ramo != '''' ';
            v_where_chart := v_where_chart || ' AND rede IS NOT NULL AND rede != '''' ';
            v_where_base := v_where_base || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
        ELSIF 'sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND (dc.ramo IS NULL OR dc.ramo = '''') ';
            v_where_chart := v_where_chart || ' AND (rede IS NULL OR rede = '''') ';
            v_where_base := v_where_base || ' AND (s.rede IS NULL OR s.rede = '''') ';
            v_where_base_prev := v_where_base_prev || ' AND (s.rede IS NULL OR s.rede = '''') ';
        ELSE
            v_where_clients := v_where_clients || ' AND dc.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base := v_where_base || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
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
            COUNT(DISTINCT CASE WHEN c.vlvenda >= 1 AND c.tipovenda NOT IN (''5'', ''11'') THEN c.codcli::text || ''-'' || c.mes::text END) as positivacao_mensal,
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
            ac.positivacao_mensal,
            COALESCE(ask.sum_skus, 0)::numeric as sum_skus,
            ac.total_pedidos::numeric as total_pedidos,
            ac.q_meses,
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
$function$;
