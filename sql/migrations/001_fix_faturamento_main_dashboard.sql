CREATE OR REPLACE FUNCTION get_main_dashboard_data(
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
    v_sql text;
    v_result json;
    v_where_base text := ' WHERE 1=1 ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';
    v_where_unnested text := ' ';
    v_mix_constraint text := '1=1';

    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';

    v_is_month_filtered boolean := false;
    v_pre_agg_skus_sql text;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '64MB';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary);
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;
    v_where_base := v_where_base || format(' AND s.ano = %L ', v_current_year);
    v_where_base_prev := v_where_base_prev || format(' AND s.ano = %L ', v_previous_year);

    IF p_mes IS NOT NULL AND p_mes != '' THEN
        v_where_base := v_where_base || format(' AND s.mes = %L ', p_mes);
        v_where_base_prev := v_where_base_prev || format(' AND s.mes = %L ', p_mes);
        v_is_month_filtered := true;
    END IF;

    -- 2. Construct WHERE clauses matching the optimized indices
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
        v_where_base_prev := v_where_base_prev || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
        v_where_clients := v_where_clients || format(' AND cb.filial = ANY(%L::text[]) ', p_filial);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE filial = ANY(%L::text[])) ', p_filial);
        v_where_chart := v_where_chart || format(' AND filial = ANY(%L::text[]) ', p_filial);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_base_prev := v_where_base_prev || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND dc.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
        v_where_chart := v_where_chart || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_base_prev := v_where_base_prev || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_clients := v_where_clients || format(' AND dc.rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE cod_superv IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE cod_superv IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
        v_where_chart := v_where_chart || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_base_prev := v_where_base_prev || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_clients := v_where_clients || format(' AND dv.nome = ANY(%L::text[]) ', p_vendedor);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_chart := v_where_chart || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
    END IF;

    -- Fornecedores Filter (Raw and JSONB Unnested)
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_unnested_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
            v_cond_str text;
            v_unnested_str text;
        BEGIN
            -- Specific fast path for just PEPSICO (707, 708, 752)
            IF p_fornecedor <@ ARRAY['707','708','752'] AND ARRAY['707','708','752'] <@ p_fornecedor THEN
                v_where_base := v_where_base || ' AND s.codfor IN (''707'',''708'',''752'') ';
                v_where_base_prev := v_where_base_prev || ' AND s.codfor IN (''707'',''708'',''752'') ';
                v_where_chart := v_where_chart || ' AND codfor IN (''707'',''708'',''752'') ';
                v_mix_constraint := 'codfor IN (''707'',''708'',''752'')';
                v_where_unnested := v_where_unnested || ' AND dp.codfor IN (''707'',''708'',''752'') ';
            ELSE
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDYNHO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDYNHO%'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDY %''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDY %'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%QUAKER%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%QUAKER%'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%KEROCOCO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%KEROCOCO%'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDYNHO%'' OR pr ILIKE ''%TODDY %'' OR pr ILIKE ''%QUAKER%'' OR pr ILIKE ''%KEROCOCO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' AND dp.descricao NOT ILIKE ''%TODDY %'' AND dp.descricao NOT ILIKE ''%QUAKER%'' AND dp.descricao NOT ILIKE ''%KEROCOCO%'')');
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
            v_where_clients := v_where_clients || format(' AND UPPER(dc.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_chart := v_where_chart || format(' AND UPPER(rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_base := v_where_base || format(' AND UPPER(s.rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_base_prev := v_where_base_prev || format(' AND UPPER(s.rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
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
            s.codcli,
            s.mes,
            s.pedido,
            s.tipovenda,
            s.vlvenda,
            s.peso,
            s.bonificacao,
            s.produtos_arr
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
            SUM(CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN CASE WHEN s.tipovenda = ANY($1) AND s.tipovenda IN (''5'',''11'') THEN s.bonificacao WHEN s.tipovenda = ANY($1) AND s.tipovenda NOT IN (''5'',''11'') THEN s.vlvenda ELSE 0 END WHEN s.tipovenda IN (''1'', ''9'') THEN s.vlvenda ELSE 0 END) as faturamento_prev
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

    client_monthly_sales AS MATERIALIZED (
        SELECT
            c.filial, c.cidade, c.codusur, c.mes, c.codcli,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END)::numeric as month_pedidos,
            SUM(CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN CASE WHEN c.tipovenda = ANY($1) AND c.tipovenda IN (''5'',''11'') THEN c.bonificacao WHEN c.tipovenda = ANY($1) AND c.tipovenda NOT IN (''5'',''11'') THEN c.vlvenda ELSE 0 END WHEN c.tipovenda IN (''1'', ''9'') THEN c.vlvenda ELSE 0 END) as sum_vlvenda
        FROM current_data c
        GROUP BY c.filial, c.cidade, c.codusur, c.mes, c.codcli
    ),
    monthly_freq AS (
        SELECT
            filial,
            cidade,
            codusur,
            mes,
            SUM(month_pedidos) as month_pedidos,
            SUM(CASE WHEN sum_vlvenda >= 1 THEN 1 ELSE 0 END)::numeric as month_clientes
        FROM client_monthly_sales
        GROUP BY filial, cidade, codusur, mes
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
            SUM(CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN CASE WHEN c.tipovenda = ANY($1) THEN c.peso ELSE 0 END ELSE CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN CASE WHEN c.tipovenda = ANY($1) AND c.tipovenda NOT IN (''5'', ''11'') THEN c.peso ELSE 0 END WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.peso ELSE 0 END END END) as tons,
            SUM(CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN CASE WHEN c.tipovenda = ANY($1) AND c.tipovenda IN (''5'',''11'') THEN c.bonificacao WHEN c.tipovenda = ANY($1) AND c.tipovenda NOT IN (''5'',''11'') THEN c.vlvenda ELSE 0 END WHEN c.tipovenda IN (''1'', ''9'') THEN c.vlvenda ELSE 0 END) as faturamento,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END) as total_pedidos,
            COUNT(DISTINCT c.mes) as q_meses
        FROM current_data c
        GROUP BY ROLLUP(c.filial, c.cidade, c.codusur)
    ),
    aggregated_positivados AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            COUNT(DISTINCT CASE WHEN sum_vlvenda >= 1 THEN codcli END) as positivacao,
            COUNT(DISTINCT CASE WHEN sum_vlvenda >= 1 THEN codcli::text || ''-'' || mes::text END) as positivacao_mensal
        FROM client_monthly_sales
        GROUP BY ROLLUP(filial, cidade, codusur)
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
            COALESCE(mf.avg_monthly_freq, 0) as avg_monthly_freq,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_curr ac
        LEFT JOIN aggregated_positivados ap
            ON ac.grp_filial = ap.grp_filial
            AND ac.grp_cidade = ap.grp_cidade
            AND ac.grp_vendedor = ap.grp_vendedor
            AND ac.filial = ap.filial
            AND ac.cidade = ap.cidade
            AND ac.vendedor_cod IS NOT DISTINCT FROM ap.vendedor_cod
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
    chart_monthly_sales AS (
        SELECT s.ano, s.mes, s.codcli,
               COUNT(DISTINCT CASE WHEN s.tipovenda NOT IN (''5'', ''11'') THEN s.pedido END) as month_pedidos,
               SUM(CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN CASE WHEN s.tipovenda = ANY($1) AND s.tipovenda IN (''5'',''11'') THEN s.bonificacao WHEN s.tipovenda = ANY($1) AND s.tipovenda NOT IN (''5'',''11'') THEN s.vlvenda ELSE 0 END WHEN s.tipovenda IN (''1'', ''9'') THEN s.vlvenda ELSE 0 END) as sum_vlvenda
        FROM public.data_summary_frequency s
        ' || v_where_chart || '
        GROUP BY s.ano, s.mes, s.codcli
    ),
    chart_data AS (
        SELECT
            ano,
            mes,
            SUM(month_pedidos) as total_pedidos,
            SUM(CASE WHEN sum_vlvenda >= 1 THEN 1 ELSE 0 END) as total_clientes
        FROM chart_monthly_sales
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

    EXECUTE v_sql INTO v_result USING p_tipovenda;
    RETURN COALESCE(v_result, '{}'::json);
END;
$$;

-- Atualiza a função get_frequency_table_data para também aplicar a correção do faturamento
-- A mesma correção é feita nos totais agrupados por mês na tabela de detalhes abaixo do gráfico de árvore

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
    v_sql text;
    v_result json;
    v_where_base text := ' WHERE 1=1 ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';
    v_where_unnested text := ' ';
    v_mix_constraint text := '1=1';

    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';

    v_is_month_filtered boolean := false;
    v_pre_agg_skus_sql text;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '64MB';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary);
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;
    v_where_base := v_where_base || format(' AND s.ano = %L ', v_current_year);
    v_where_base_prev := v_where_base_prev || format(' AND s.ano = %L ', v_previous_year);

    IF p_mes IS NOT NULL AND p_mes != '' THEN
        v_where_base := v_where_base || format(' AND s.mes = %L ', p_mes);
        v_where_base_prev := v_where_base_prev || format(' AND s.mes = %L ', p_mes);
        v_is_month_filtered := true;
    END IF;

    -- 2. Construct WHERE clauses matching the optimized indices
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
        v_where_base_prev := v_where_base_prev || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
        v_where_clients := v_where_clients || format(' AND cb.filial = ANY(%L::text[]) ', p_filial);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE filial = ANY(%L::text[])) ', p_filial);
        v_where_chart := v_where_chart || format(' AND filial = ANY(%L::text[]) ', p_filial);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_base_prev := v_where_base_prev || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND dc.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
        v_where_chart := v_where_chart || format(' AND cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_base_prev := v_where_base_prev || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_clients := v_where_clients || format(' AND dc.rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE cod_superv IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE cod_superv IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
        v_where_chart := v_where_chart || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_base_prev := v_where_base_prev || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_clients := v_where_clients || format(' AND dv.nome = ANY(%L::text[]) ', p_vendedor);
        v_where_kpi := v_where_kpi || format(' AND rca1 IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        v_where_chart := v_where_chart || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
    END IF;

    -- Fornecedores Filter (Raw and JSONB Unnested)
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_unnested_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
            v_cond_str text;
            v_unnested_str text;
        BEGIN
            -- Specific fast path for just PEPSICO (707, 708, 752)
            IF p_fornecedor <@ ARRAY['707','708','752'] AND ARRAY['707','708','752'] <@ p_fornecedor THEN
                v_where_base := v_where_base || ' AND s.codfor IN (''707'',''708'',''752'') ';
                v_where_base_prev := v_where_base_prev || ' AND s.codfor IN (''707'',''708'',''752'') ';
                v_where_chart := v_where_chart || ' AND codfor IN (''707'',''708'',''752'') ';
                v_mix_constraint := 'codfor IN (''707'',''708'',''752'')';
                v_where_unnested := v_where_unnested || ' AND dp.codfor IN (''707'',''708'',''752'') ';
            ELSE
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDYNHO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDYNHO%'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDY %''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDY %'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%QUAKER%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%QUAKER%'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%KEROCOCO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao ILIKE ''%KEROCOCO%'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.produtos) pr WHERE pr ILIKE ''%TODDYNHO%'' OR pr ILIKE ''%TODDY %'' OR pr ILIKE ''%QUAKER%'' OR pr ILIKE ''%KEROCOCO%''))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' AND dp.descricao NOT ILIKE ''%TODDY %'' AND dp.descricao NOT ILIKE ''%QUAKER%'' AND dp.descricao NOT ILIKE ''%KEROCOCO%'')');
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
            v_where_clients := v_where_clients || format(' AND UPPER(dc.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_chart := v_where_chart || format(' AND UPPER(rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_base := v_where_base || format(' AND UPPER(s.rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_base_prev := v_where_base_prev || format(' AND UPPER(s.rede) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
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
    filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda, codfor, categoria_produto
        FROM public.data_summary
        ' || v_where_base || '
    ),
    monthly_counts AS (
        SELECT ano, mes, COUNT(*) as active_count
        FROM (
            SELECT ano, mes, codcli, SUM(vlvenda) as total_vlvenda, SUM(bonificacao) as total_bonificacao
            FROM filtered_summary
            WHERE (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND tipovenda = ANY($1) )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND
                  (CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1) ELSE tipovenda NOT IN (''5'', ''11'') END)
                )
            )
            GROUP BY ano, mes, codcli
            HAVING (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
            )
        ) grouped_clients
        GROUP BY ano, mes
    ),
    agg_data AS (
        SELECT
            fs.ano,
            fs.mes,
            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao WHEN fs.tipovenda = ANY($1) AND fs.tipovenda NOT IN (''5'', ''11'') THEN fs.vlvenda ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') THEN fs.vlvenda
                ELSE 0
            END) as faturamento,

            SUM(CASE
                WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.vlvenda
                ELSE 0
            END) as total_sold_base,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) THEN fs.peso ELSE 0 END
                ELSE
                    CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                             CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso ELSE 0 END
                        WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso
                        ELSE 0
                    END
            END) as peso,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 && ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
                ELSE
                     CASE WHEN fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
            END) as bonificacao,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.devolucao ELSE 0 END
                ELSE fs.devolucao
            END) as devolucao,

            COALESCE(MAX(mc.active_count), 0) as positivacao_count,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.pre_mix_count ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') AND (' || v_mix_constraint || ') THEN fs.pre_mix_count
                ELSE 0
            END) as total_mix_sum,

            COUNT(DISTINCT CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) AND fs.pre_mix_count > 0 THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.codcli ELSE NULL END
                WHEN fs.tipovenda IN (''1'', ''9'') AND fs.pre_mix_count > 0 AND (' || v_mix_constraint || ') THEN fs.codcli
                ELSE NULL
            END) as mix_client_count
        FROM filtered_summary fs
        LEFT JOIN monthly_counts mc ON fs.ano = mc.ano AND fs.mes = mc.mes
        GROUP BY fs.ano, fs.mes
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
            SELECT codcli
            FROM filtered_summary
            WHERE ano = $2
            ' || CASE WHEN v_is_month_filtered THEN ' AND mes = $3 ' ELSE '' END || '
            AND (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND tipovenda = ANY($1) )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND
                  (CASE WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1) ELSE tipovenda NOT IN (''5'', ''11'') END)
                )
            )
            GROUP BY codcli
            HAVING (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
            )
        ) grouped_active_clients
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients
        ' || v_where_kpi || '
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $2), ''[]''::json),

        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $4), ''[]''::json)
    FROM agg_data a;
    ';

    EXECUTE v_sql INTO
        v_result
    USING p_tipovenda, v_current_year, p_mes::int, v_previous_year;

    RETURN v_result;
END;
$$;
