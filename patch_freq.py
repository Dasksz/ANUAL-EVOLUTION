import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# Replace the get_frequency_table_data function entirely

new_func = """
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

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';

    v_sql text;
    v_result json;
BEGIN
    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        SELECT EXTRACT(YEAR FROM MAX(dtped)) INTO v_current_year FROM public.data_detailed;
        v_current_year := COALESCE(v_current_year, EXTRACT(YEAR FROM CURRENT_DATE));
    ELSE
        v_current_year := p_ano::int;
    END IF;

    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int;
        v_where_base := v_where_base || ' AND ano = ' || v_current_year || ' AND mes = ' || v_target_month || ' ';
        v_where_base_prev := v_where_base_prev || ' AND ano = ' || v_previous_year || ' AND mes = ' || v_target_month || ' ';
    ELSE
        v_where_base := v_where_base || ' AND ano = ' || v_current_year || ' ';
        v_where_base_prev := v_where_base_prev || ' AND ano = ' || v_previous_year || ' ';
    END IF;

    v_where_chart := v_where_chart || ' AND ano IN (' || v_previous_year || ', ' || v_current_year || ') ';

    -- 2. Build Where Clauses
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_base := v_where_base || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_clients := v_where_clients || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_chart := v_where_chart || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_chart := v_where_chart || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_base := v_where_base || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_where_base := v_where_base || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_clients := v_where_clients || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_base := v_where_base || ' AND produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND produtos ?| ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || ' AND categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND categorias ?| ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || ' AND tipovenda = ANY(ARRAY[' || array_to_string(p_tipovenda, ',') || ']) ';
        v_where_base_prev := v_where_base_prev || ' AND tipovenda = ANY(ARRAY[' || array_to_string(p_tipovenda, ',') || ']) ';
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[' || array_to_string(p_tipovenda, ',') || ']) ';
    END IF;

    -- Dynamic Query
    v_sql := '
    WITH current_data AS (
        SELECT
            COALESCE(all_sales.filial, ''SEM FILIAL'') as filial,
            COALESCE(all_sales.cidade, ''SEM CIDADE'') as cidade,
            COALESCE(dv.nome, ''SEM VENDEDOR'') as vendedor,
            all_sales.codcli,
            all_sales.pedido,
            all_sales.tipovenda,
            all_sales.vlvenda,
            all_sales.peso,
            all_sales.produtos,
            all_sales.categorias
        FROM public.dat_summary_frequency all_sales
        LEFT JOIN public.dim_vendedores dv ON all_sales.codusur = dv.codigo
        ' || v_where_base || '
    ),
    previous_data AS (
        SELECT
            COALESCE(all_sales.filial, ''SEM FILIAL'') as filial,
            COALESCE(all_sales.cidade, ''SEM CIDADE'') as cidade,
            COALESCE(dv.nome, ''SEM VENDEDOR'') as vendedor,
            SUM(all_sales.vlvenda) as faturamento_prev
        FROM public.dat_summary_frequency all_sales
        LEFT JOIN public.dim_vendedores dv ON all_sales.codusur = dv.codigo
        ' || v_where_base_prev || '
        GROUP BY 1, 2, 3
    ),
    client_base AS (
        SELECT
            ''SEM FILIAL''::text as filial,
            COALESCE(cidade, ''SEM CIDADE'') as cidade,
            COUNT(DISTINCT codigo_cliente) as base_total
        FROM public.data_clients
        ' || v_where_clients || '
        GROUP BY 1, 2
    ),
    aggregated_curr AS (
        SELECT
            filial,
            cidade,
            vendedor,
            SUM(peso) as tons,
            SUM(vlvenda) as faturamento,
            COUNT(DISTINCT codcli) as positivacao
        FROM current_data c
        GROUP BY filial, cidade, vendedor
    ),
    mix_per_client AS (
        SELECT
            filial,
            cidade,
            vendedor,
            codcli,
            (SELECT COUNT(DISTINCT el) FROM (SELECT jsonb_array_elements_text(produtos) as el FROM current_data cd2 WHERE cd2.filial = current_data.filial AND cd2.cidade = current_data.cidade AND cd2.vendedor = current_data.vendedor AND cd2.codcli = current_data.codcli) sub) as skus
        FROM current_data
        GROUP BY filial, cidade, vendedor, codcli
    ),
    mix_agg AS (
        SELECT filial, cidade, vendedor, SUM(skus) as sum_skus
        FROM mix_per_client
        GROUP BY filial, cidade, vendedor
    ),
    freq_pedidos AS (
        SELECT filial, cidade, vendedor, COUNT(DISTINCT pedido) as total_pedidos
        FROM current_data
        WHERE tipovenda NOT IN (''5'', ''11'')
        GROUP BY filial, cidade, vendedor
    ),
    final_tree AS (
        SELECT
            ac.filial,
            ac.cidade,
            ac.vendedor,
            ac.tons,
            ac.faturamento,
            COALESCE(pd.faturamento_prev, 0) as faturamento_prev,
            ac.positivacao,
            COALESCE(ma.sum_skus, 0) as sum_skus,
            COALESCE(fp.total_pedidos, 0) as total_pedidos,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_curr ac
        LEFT JOIN previous_data pd ON ac.filial = pd.filial AND ac.cidade = pd.cidade AND ac.vendedor = pd.vendedor
        LEFT JOIN mix_agg ma ON ac.filial = ma.filial AND ac.cidade = ma.cidade AND ac.vendedor = ma.vendedor
        LEFT JOIN freq_pedidos fp ON ac.filial = fp.filial AND ac.cidade = fp.cidade AND ac.vendedor = fp.vendedor
        LEFT JOIN client_base cb ON ac.filial = cb.filial AND ac.cidade = cb.cidade
    ),
    chart_data AS (
        SELECT
            ano,
            mes,
            COUNT(DISTINCT pedido) as total_pedidos,
            COUNT(DISTINCT codcli) as total_clientes
        FROM public.dat_summary_frequency
        ' || v_where_chart || ' AND tipovenda NOT IN (''5'', ''11'')
        GROUP BY 1, 2
    )
    SELECT json_build_object(
        ''tree_data'', (SELECT COALESCE(json_agg(row_to_json(final_tree)), ''[]''::json) FROM final_tree),
        ''chart_data'', (SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data),
        ''current_year'', ' || v_current_year || ',
        ''previous_year'', ' || v_previous_year || '
    );
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;
"""

old_func_pattern = re.compile(r'CREATE OR REPLACE FUNCTION get_frequency_table_data.*?END;\n\$\$;', re.DOTALL)
content = old_func_pattern.sub(new_func.strip(), content)

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)

print("Replaced get_frequency_table_data")
