DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text[], text[], text[], text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text, text, text[], text[], text[], text[], text[], text[], text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text, text, text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text, text, text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text, text, text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text, text);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[], text);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[], text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data(text[]);
DROP FUNCTION IF EXISTS get_frequency_table_data();


CREATE OR REPLACE FUNCTION get_frequency_table_data(
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
    v_eval_target_month int;
    v_max_current_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_unnested text := ' ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';
    v_pre_agg_skus_sql text;

    v_result json;
    v_sql text;
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '600s';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary_frequency);
    ELSE
        v_current_year := p_ano::int;
    END IF;

    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' AND s.mes = ' || v_target_month || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' AND s.mes = ' || v_target_month || ' ';
    ELSE
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' ';

        -- PROPORTIONAL YAGO (Year-Ago): Se for o ano todo, o ano passado deve comparar apenas até o mês máximo que tem dados no ano atual.
        SELECT COALESCE(MAX(mes), 12) INTO v_max_current_month FROM public.data_summary_frequency WHERE ano = v_current_year;

        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' AND s.mes <= ' || v_max_current_month || ' ';
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
            DECLARE
                v_code text;
                v_conditions text[] := '{}';
                v_unnested_conditions text[] := '{}';
                v_simple_codes text[] := '{}';
                v_cond_str text;
                v_unnested_str text;
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDYNHO''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''TODDYNHO'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDY''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''TODDY'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''QUAKER''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''QUAKER'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''KEROCOCO''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''KEROCOCO'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias_arr && ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto NOT IN (''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO''))');
                    ELSE
                        v_simple_codes := array_append(v_simple_codes, v_code);
                    END IF;
                END LOOP;

                IF array_length(v_simple_codes, 1) > 0 THEN
                    v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                    v_unnested_conditions := array_append(v_unnested_conditions, format('dp.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                END IF;

                IF array_length(v_conditions, 1) > 0 THEN
                    v_cond_str := array_to_string(v_conditions, ' OR ');
                    v_unnested_str := array_to_string(v_unnested_conditions, ' OR ');

                    v_where_base := v_where_base || ' AND (' || v_cond_str || ') ';
                    v_where_base_prev := v_where_base_prev || ' AND (' || v_cond_str || ') ';
                    -- for chart alias 'codfor' is actually 's.codfor' in the view so we just string replace 's.' with '' for v_where_chart if necessary, but actually current_data in get_frequency_table_data has no alias prefix in monthly_freq, so let's use the CTE column name which is 'codfor' and 'categorias'
                    v_where_chart := v_where_chart || ' AND (' || replace(v_cond_str, 's.', '') || ') ';

                    IF v_unnested_str <> '' THEN
                        v_where_unnested := v_where_unnested || ' AND (' || v_unnested_str || ') ';
                    END IF;
                END IF;
            END;
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
        v_where_base := v_where_base || ' AND s.produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_unnested := v_where_unnested || ' AND dp.descricao = ANY(ARRAY[''' || array_to_string(p_produto, ''',''') || ''']) ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_unnested := v_where_unnested || ' AND dp.categoria_produto = ANY(ARRAY[''' || array_to_string(p_categoria, ''',''') || ''']) ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    IF v_where_unnested = ' ' OR v_where_unnested = '' THEN
        v_pre_agg_skus_sql := '
        SELECT
            c.filial, c.cidade, c.codusur, c.codcli,
            COUNT(DISTINCT p.produto) as dist_skus_per_cli
        FROM current_data c
        CROSS JOIN LATERAL unnest(c.produtos_arr) AS p(produto)
        WHERE c.tipovenda NOT IN (''5'', ''11'') AND c.vlvenda >= 1
        GROUP BY c.filial, c.cidade, c.codusur, c.codcli
        ';
    ELSE
        v_pre_agg_skus_sql := '
        SELECT
            c.filial, c.cidade, c.codusur, c.codcli,
            COUNT(DISTINCT dp.codigo) as dist_skus_per_cli
        FROM current_data c
        CROSS JOIN LATERAL unnest(c.produtos_arr) AS p(produto)
        INNER JOIN public.dim_produtos dp ON dp.codigo = p.produto
        WHERE c.tipovenda NOT IN (''5'', ''11'') AND c.vlvenda >= 1
        ' || v_where_unnested || '
        GROUP BY c.filial, c.cidade, c.codusur, c.codcli
        ';
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
    current_data AS MATERIALIZED (
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
            s.produtos,
            s.produtos_arr,
            s.categorias_arr
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
    pre_aggregated_skus AS (
        ' || v_pre_agg_skus_sql || '
    ),
    aggregated_skus AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            SUM(dist_skus_per_cli) as sum_skus
        FROM pre_aggregated_skus
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),
    aggregated_current AS (
        SELECT
            GROUPING(c.filial) as grp_filial,
            GROUPING(c.cidade) as grp_cidade,
            GROUPING(c.codusur) as grp_vendedor,
            COALESCE(c.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(c.cidade, ''TOTAL_CIDADE'') as cidade,
            c.codusur as vendedor_cod,
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.peso ELSE 0 END) as tons,
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.vlvenda ELSE 0 END) as faturamento,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') AND c.vlvenda >= 1 THEN c.pedido END) as total_pedidos,
            COUNT(DISTINCT c.mes) as q_meses
        FROM current_data c
        GROUP BY ROLLUP(c.filial, c.cidade, c.codusur)
    ),
    positivacao_data AS (
        SELECT
            GROUPING(c.filial) as grp_filial,
            GROUPING(c.cidade) as grp_cidade,
            GROUPING(c.codusur) as grp_vendedor,
            COALESCE(c.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(c.cidade, ''TOTAL_CIDADE'') as cidade,
            c.codusur as vendedor_cod,
            COUNT(DISTINCT c.codcli) as positivacao,
            -- Average monthly positivacao: SUM(clients_per_month) / q_meses
            SUM(c.cli_mensal_count) / NULLIF((SELECT MAX(q_meses) FROM aggregated_current), 0) as positivacao_mensal
        FROM (
            SELECT filial, cidade, codusur, codcli, mes, 1 as cli_mensal_count
            FROM current_data
            WHERE tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1
            GROUP BY filial, cidade, codusur, codcli, mes
        ) c
        GROUP BY ROLLUP(c.filial, c.cidade, c.codusur)
    ),
    tree_data AS (
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
            COALESCE(ap.positivacao, 0) as positivacao,
            COALESCE(ap.positivacao_mensal, 0) as positivacao_mensal,
            COALESCE(ask.sum_skus, 0)::numeric as sum_skus,
            ac.total_pedidos::numeric as total_pedidos,
            ac.q_meses,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_current ac
        LEFT JOIN previous_data pd ON pd.filial = ac.filial AND pd.cidade = ac.cidade AND pd.vendedor_cod IS NOT DISTINCT FROM ac.vendedor_cod AND pd.grp_filial = ac.grp_filial AND pd.grp_cidade = ac.grp_cidade AND pd.grp_vendedor = ac.grp_vendedor
        LEFT JOIN aggregated_skus ask ON ask.filial = ac.filial AND ask.cidade = ac.cidade AND ask.vendedor_cod IS NOT DISTINCT FROM ac.vendedor_cod AND ask.grp_filial = ac.grp_filial AND ask.grp_cidade = ac.grp_cidade AND ask.grp_vendedor = ac.grp_vendedor
        LEFT JOIN positivacao_data ap ON ap.filial = ac.filial AND ap.cidade = ac.cidade AND ap.vendedor_cod IS NOT DISTINCT FROM ac.vendedor_cod AND ap.grp_filial = ac.grp_filial AND ap.grp_cidade = ac.grp_cidade AND ap.grp_vendedor = ac.grp_vendedor
        LEFT JOIN client_base cb ON cb.filial = ac.filial AND cb.cidade = ac.cidade AND cb.grp_filial = ac.grp_filial AND cb.grp_cidade = ac.grp_cidade AND cb.grp_vendedor = ac.grp_vendedor AND
            (cb.vendedor = COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1), ''SEM VENDEDOR'') OR ac.grp_vendedor = 1)
        ORDER BY ac.grp_filial DESC, ac.grp_cidade DESC, ac.grp_vendedor DESC, ac.faturamento DESC
    ),
    monthly_freq AS (
        SELECT
            mes,
            SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN vlvenda ELSE 0 END) as vlvenda
        FROM public.data_summary_frequency s
        ' || v_where_chart || '
        GROUP BY mes
        ORDER BY mes
    )
    SELECT json_build_object(
        ''tree_data'', COALESCE((SELECT json_agg(t) FROM tree_data t), ''[]''::json),
        ''monthly_freq'', COALESCE((SELECT json_agg(m) FROM monthly_freq m), ''[]''::json)
    );
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in get_frequency_table_data: % %', SQLERRM, SQLSTATE;
        RETURN json_build_object('error', SQLERRM);
END;
$$;

ALTER FUNCTION public.get_frequency_table_data(p_filial text[], p_cidade text[], p_supervisor text[], p_vendedor text[], p_fornecedor text[], p_ano text, p_mes text, p_tipovenda text[], p_rede text[], p_produto text[], p_categoria text[]) SET search_path = public;
