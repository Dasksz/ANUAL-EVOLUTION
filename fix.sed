/WITH current_data AS (/,/chart_data AS (/ c\
    WITH current_data AS (\
        SELECT\
            COALESCE(s.filial, ''SEM FILIAL'') as filial,\
            COALESCE(s.cidade, ''SEM CIDADE'') as cidade,\
            COALESCE(dv.nome, ''SEM VENDEDOR'') as vendedor,\
            s.codcli,\
            s.pedido,\
            s.tipovenda,\
            s.vlvenda,\
            s.peso,\
            s.produtos\
        FROM public.data_summary_frequency s\
        LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo\
        ' || v_where_base || '\
    ),\
    previous_data AS (\
        SELECT\
            GROUPING(COALESCE(s.filial, ''SEM FILIAL'')) as grp_filial,\
            GROUPING(COALESCE(s.cidade, ''SEM CIDADE'')) as grp_cidade,\
            GROUPING(COALESCE(dv.nome, ''SEM VENDEDOR'')) as grp_vendedor,\
            COALESCE(COALESCE(s.filial, ''SEM FILIAL''), ''TOTAL_GERAL'') as filial,\
            COALESCE(COALESCE(s.cidade, ''SEM CIDADE''), ''TOTAL_CIDADE'') as cidade,\
            COALESCE(COALESCE(dv.nome, ''SEM VENDEDOR''), ''TOTAL_VENDEDOR'') as vendedor,\
            SUM(s.vlvenda) as faturamento_prev\
        FROM public.data_summary_frequency s\
        LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo\
        ' || v_where_base_prev || ' AND s.tipovenda NOT IN (''5'', ''11'')\
        GROUP BY ROLLUP(COALESCE(s.filial, ''SEM FILIAL''), COALESCE(s.cidade, ''SEM CIDADE''), COALESCE(dv.nome, ''SEM VENDEDOR''))\
    ),\
    client_base AS (\
        SELECT\
            GROUPING(COALESCE(filial, ''SEM FILIAL'')) as grp_filial,\
            GROUPING(COALESCE(cidade, ''SEM CIDADE'')) as grp_cidade,\
            COALESCE(COALESCE(filial, ''SEM FILIAL''), ''TOTAL_GERAL'') as filial,\
            COALESCE(COALESCE(cidade, ''SEM CIDADE''), ''TOTAL_CIDADE'') as cidade,\
            COUNT(DISTINCT codigo_cliente) as base_total\
        FROM public.data_clients\
        ' || v_where_clients || '\
        GROUP BY ROLLUP(COALESCE(filial, ''SEM FILIAL''), COALESCE(cidade, ''SEM CIDADE''))\
    ),\
    client_totals AS (\
        SELECT filial, cidade, vendedor, codcli,\
               SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN vlvenda ELSE 0 END) as total_vlvenda\
        FROM current_data\
        GROUP BY filial, cidade, vendedor, codcli\
    ),\
    valid_clients AS (\
        SELECT filial, cidade, vendedor, codcli\
        FROM client_totals\
        WHERE total_vlvenda >= 1\
    ),\
    current_skus AS (\
        SELECT filial, cidade, vendedor, codcli, jsonb_array_elements_text(produtos) as sku\
        FROM current_data\
        WHERE tipovenda NOT IN (''5'', ''11'')\
    ),\
    aggregated_curr AS (\
        SELECT\
            GROUPING(c.filial) as grp_filial,\
            GROUPING(c.cidade) as grp_cidade,\
            GROUPING(c.vendedor) as grp_vendedor,\
            COALESCE(c.filial, ''TOTAL_GERAL'') as filial,\
            COALESCE(c.cidade, ''TOTAL_CIDADE'') as cidade,\
            COALESCE(c.vendedor, ''TOTAL_VENDEDOR'') as vendedor,\
            SUM(c.peso) as tons,\
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.vlvenda ELSE 0 END) as faturamento,\
            COUNT(DISTINCT vc.codcli) as positivacao,\
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END) as total_pedidos\
        FROM current_data c\
        LEFT JOIN valid_clients vc ON c.filial = vc.filial AND c.cidade = vc.cidade AND c.vendedor = vc.vendedor AND c.codcli = vc.codcli AND c.tipovenda NOT IN (''5'', ''11'')\
        GROUP BY ROLLUP(c.filial, c.cidade, c.vendedor)\
    ),\
    aggregated_skus AS (\
        SELECT\
            GROUPING(filial) as grp_filial,\
            GROUPING(cidade) as grp_cidade,\
            GROUPING(vendedor) as grp_vendedor,\
            COALESCE(filial, ''TOTAL_GERAL'') as filial,\
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,\
            COALESCE(vendedor, ''TOTAL_VENDEDOR'') as vendedor,\
            COUNT(DISTINCT codcli || ''-'' || sku) as sum_skus\
        FROM current_skus\
        GROUP BY ROLLUP(filial, cidade, vendedor)\
    ),\
    final_tree AS (\
        SELECT\
            ac.grp_filial,\
            ac.grp_cidade,\
            ac.grp_vendedor,\
            ac.filial,\
            ac.cidade,\
            ac.vendedor,\
            ac.tons,\
            ac.faturamento,\
            COALESCE(pd.faturamento_prev, 0) as faturamento_prev,\
            ac.positivacao,\
            COALESCE(ask.sum_skus, 0) as sum_skus,\
            ac.total_pedidos,\
            COALESCE(cb.base_total, 0) as base_total\
        FROM aggregated_curr ac\
        LEFT JOIN previous_data pd ON ac.grp_filial = pd.grp_filial \
                                  AND ac.grp_cidade = pd.grp_cidade \
                                  AND ac.grp_vendedor = pd.grp_vendedor \
                                  AND ac.filial = pd.filial \
                                  AND ac.cidade = pd.cidade \
                                  AND ac.vendedor = pd.vendedor\
        LEFT JOIN aggregated_skus ask ON ac.grp_filial = ask.grp_filial \
                                  AND ac.grp_cidade = ask.grp_cidade \
                                  AND ac.grp_vendedor = ask.grp_vendedor \
                                  AND ac.filial = ask.filial \
                                  AND ac.cidade = ask.cidade \
                                  AND ac.vendedor = ask.vendedor\
        LEFT JOIN client_base cb ON ac.grp_filial = cb.grp_filial \
                                AND ac.grp_cidade = cb.grp_cidade \
                                AND ac.grp_vendedor = 1 \
                                AND ac.filial = cb.filial \
                                AND ac.cidade = cb.cidade\
    ),\
    chart_data AS (
