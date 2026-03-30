-- Migration to fix specific supplier filtering (e.g., 1119_TODDYNHO) in get_frequency_table_data
-- Without this, ANY specific supplier selection applies an "OR codfor LIKE '1119_%'" causing broad unintended inclusions.

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
        v_target_month := p_mes::int + 1;
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' AND s.mes = ' || v_target_month || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' AND s.mes = ' || v_target_month || ' ';
    ELSE
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' ';
    END IF;

    v_where_chart := v_where_chart || ' AND ano IN (' || v_previous_year || ', ' || v_current_year || ') ';

    -- 2. Build Where Clauses
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
            IF ('1119' = ANY(p_fornecedor)) THEN
                v_where_base := v_where_base || ' AND (
                    s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR s.codfor LIKE ''1119_%''
                ) ';
                v_where_base_prev := v_where_base_prev || ' AND (
                    s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR s.codfor LIKE ''1119_%''
                ) ';
                v_where_chart := v_where_chart || ' AND (
                    codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || '''])
                    OR codfor LIKE ''1119_%''
                ) ';
            ELSE
                v_where_base := v_where_base || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
                v_where_base_prev := v_where_base_prev || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
                v_where_chart := v_where_chart || ' AND codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
            END IF;
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
        WHERE tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1
    ),
    pre_aggregated_skus AS (
        SELECT
            filial, cidade, codusur, codcli,
            COUNT(DISTINCT sku) as dist_skus_per_cli
        FROM current_skus
        GROUP BY filial, cidade, codusur, codcli
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
            SUM(dist_skus_per_cli) as sum_skus
        FROM pre_aggregated_skus
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),
    final_tree AS (
        SELECT
            ac.filial,
            ac.cidade,
            ac.vendedor_cod,
            ac.grp_filial,
            ac.grp_cidade,
            ac.grp_vendedor,
            ac.tons as kpi_tons,
            ac.faturamento as kpi_fat,
            COALESCE(pd.faturamento_prev, 0) as kpi_fat_prev,
            ac.positivacao as kpi_positivacao,
            cb.base_total as kpi_base_total,
            ac.total_pedidos as raw_total_pedidos,
            ac.positivacao_mensal as kpi_positivacao_mensal,
            rmf.avg_monthly_freq as kpi_frequencia,
            ask.sum_skus as raw_sum_skus,

            COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1), ac.vendedor_cod) as vendedor_nome

        FROM aggregated_curr ac
        LEFT JOIN previous_data pd
            ON ac.filial = pd.filial
            AND ac.cidade = pd.cidade
            AND ac.vendedor_cod = pd.vendedor_cod
            AND ac.grp_filial = pd.grp_filial
            AND ac.grp_cidade = pd.grp_cidade
            AND ac.grp_vendedor = pd.grp_vendedor
        LEFT JOIN client_base cb
            ON ac.filial = cb.filial
            AND ac.cidade = cb.cidade
            AND (
                -- Root total logic
                (ac.grp_filial = 1 AND ac.grp_cidade = 1 AND ac.grp_vendedor = 1 AND cb.grp_filial = 1 AND cb.grp_cidade = 1 AND cb.grp_vendedor = 1)
                -- Filial total logic
                OR (ac.grp_filial = 0 AND ac.grp_cidade = 1 AND ac.grp_vendedor = 1 AND ac.filial = cb.filial AND cb.grp_filial = 0 AND cb.grp_cidade = 1 AND cb.grp_vendedor = 1)
                -- Cidade total logic
                OR (ac.grp_filial = 0 AND ac.grp_cidade = 0 AND ac.grp_vendedor = 1 AND ac.filial = cb.filial AND ac.cidade = cb.cidade AND cb.grp_filial = 0 AND cb.grp_cidade = 0 AND cb.grp_vendedor = 1)
                -- Vendedor row logic
                OR (ac.grp_filial = 0 AND ac.grp_cidade = 0 AND ac.grp_vendedor = 0 AND ac.filial = cb.filial AND ac.cidade = cb.cidade AND cb.grp_filial = 0 AND cb.grp_cidade = 0 AND cb.grp_vendedor = 0 AND
                    cb.vendedor = COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1), ac.vendedor_cod))
            )
        LEFT JOIN aggregated_skus ask
            ON ac.filial = ask.filial
            AND ac.cidade = ask.cidade
            AND ac.vendedor_cod = ask.vendedor_cod
            AND ac.grp_filial = ask.grp_filial
            AND ac.grp_cidade = ask.grp_cidade
            AND ac.grp_vendedor = ask.grp_vendedor
        LEFT JOIN rolled_monthly_freq rmf
            ON ac.filial = rmf.filial
            AND ac.cidade = rmf.cidade
            AND ac.vendedor_cod = rmf.vendedor_cod
            AND ac.grp_filial = rmf.grp_filial
            AND ac.grp_cidade = rmf.grp_cidade
            AND ac.grp_vendedor = rmf.grp_vendedor
    ),

    chart_months AS (
        SELECT
            mes,
            COUNT(DISTINCT CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN pedido END) as month_pedidos,
            COUNT(DISTINCT CASE WHEN vlvenda >= 1 AND tipovenda NOT IN (''5'', ''11'') THEN codcli END) as month_clientes
        FROM public.data_summary_frequency
        ' || v_where_chart || ' AND ano = ' || v_current_year || '
        GROUP BY mes
    ),
    chart_data AS (
        SELECT
            mes,
            CASE WHEN month_clientes > 0 THEN (month_pedidos::numeric / month_clientes::numeric) ELSE 0 END as freq_val
        FROM chart_months
        ORDER BY mes
    )

    SELECT json_build_object(
        ''tree'', (SELECT COALESCE(json_agg(row_to_json(final_tree)), ''[]'') FROM final_tree),
        ''chart'', (SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]'') FROM chart_data)
    ) INTO v_result;

    RETURN v_result;
END;
$$;
