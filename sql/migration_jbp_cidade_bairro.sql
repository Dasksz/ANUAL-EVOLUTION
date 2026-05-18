CREATE OR REPLACE FUNCTION get_jbp_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
    p_categoria text[] default null,
    p_ano text default null,
    p_clientes text[] default null,
    p_redes_adicionadas text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_where text := ' WHERE 1=1 ';
    v_where_rede text := '';
    v_sql text;
    v_result json;
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Build Base Filters (alias 's' for data_detailed/history)
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_where := v_where || format(' AND EXTRACT(YEAR FROM s.dtped)::int IN (%s, %s) ', p_ano::int, p_ano::int - 1);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where := v_where || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND s.codfor = ANY(%L::text[]) ', p_fornecedor);
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where := v_where || format(' AND s.produto = ANY(%L::text[]) ', p_produto);
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND dp.categoria_produto = ANY(%L::text[]) ', p_categoria);
    END IF;

    -- JBP Specific Filters: OR condition for Redes vs Clientes
    IF (p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0) OR (p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0) THEN
        v_where_rede := ' AND (';
        IF p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0 THEN
            v_where_rede := v_where_rede || format(' s.codcli = ANY(%L::text[]) ', p_clientes);
        END IF;

        IF p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0 THEN
            IF p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0 THEN
                v_where_rede := v_where_rede || ' OR ';
            END IF;
            v_where_rede := v_where_rede || format(' c.ramo = ANY(%L::text[]) ', p_redes_adicionadas);
        END IF;
        v_where_rede := v_where_rede || ') ';

        v_where := v_where || v_where_rede;
    ELSE
        -- Se não tiver nem cliente nem rede, retorna array vazio para não pesar a query
        RETURN '[]'::json;
    END IF;


    -- Dynamic SQL: Union of detailed and history
    v_sql := format('
        WITH inovacoes AS (
            SELECT codigo FROM public.data_innovations WHERE codigo IS NOT NULL
        ),
        raw_union AS (
            SELECT
                EXTRACT(YEAR FROM s.dtped)::int as ano,
                EXTRACT(MONTH FROM s.dtped)::int as mes,
                c.codigo_cliente as codcli,
                MAX(c.razaosocial) as cliente_nome,
                MAX(c.bairro) as bairro,
                MAX(c.cidade) as cidade,
                c.ramo as rede,
                s.tipovenda,
                SUM(COALESCE(s.vlvenda, 0)) as vlvenda,
                SUM(COALESCE(s.totpesoliq, 0)) as peso,
                SUM(COALESCE(s.qtvenda, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas,
                SUM(COALESCE(s.vldevolucao, 0)) as devolucao,
                SUM(COALESCE(s.vlbonific, 0)) as bonificacao,
                COUNT(DISTINCT CASE WHEN s.produto IN (SELECT codigo FROM inovacoes) THEN s.pedido ELSE NULL END) as inovacao_pedidos
            FROM public.data_detailed s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s
            GROUP BY 1, 2, 3, 7, 8
            UNION ALL
            SELECT
                EXTRACT(YEAR FROM s.dtped)::int as ano,
                EXTRACT(MONTH FROM s.dtped)::int as mes,
                c.codigo_cliente as codcli,
                MAX(c.razaosocial) as cliente_nome,
                MAX(c.bairro) as bairro,
                MAX(c.cidade) as cidade,
                c.ramo as rede,
                s.tipovenda,
                SUM(COALESCE(s.vlvenda, 0)) as vlvenda,
                SUM(COALESCE(s.totpesoliq, 0)) as peso,
                SUM(COALESCE(s.qtvenda, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as caixas,
                SUM(COALESCE(s.vldevolucao, 0)) as devolucao,
                SUM(COALESCE(s.vlbonific, 0)) as bonificacao,
                COUNT(DISTINCT CASE WHEN s.produto IN (SELECT codigo FROM inovacoes) THEN s.pedido ELSE NULL END) as inovacao_pedidos
            FROM public.data_history s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s
            GROUP BY 1, 2, 3, 7, 8
        ),
        base_data AS (
            SELECT
                ano,
                mes,
                codcli,
                MAX(cliente_nome) as cliente_nome,
                MAX(bairro) as bairro,
                MAX(cidade) as cidade,
                rede,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN vlvenda ELSE 0 END) as faturamento,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN peso ELSE 0 END) as peso,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN caixas ELSE 0 END) as caixas,
                SUM(CASE WHEN tipovenda = ''5'' THEN vlvenda + COALESCE(devolucao,0) + COALESCE(bonificacao,0) ELSE 0 END) as perda_valor,
                SUM(CASE WHEN tipovenda = ''11'' THEN vlvenda + COALESCE(bonificacao,0) ELSE 0 END) as bonificacao_valor,
                MAX(CASE WHEN tipovenda NOT IN (''5'', ''11'') AND vlvenda >= 1 THEN 1 ELSE 0 END) as positivado,
                MAX(CASE WHEN tipovenda NOT IN (''5'', ''11'') AND inovacao_pedidos > 0 THEN 1 ELSE 0 END) as inovou
            FROM raw_union
            GROUP BY 1, 2, 3, 7
        ),
        monthly_agg AS (
            SELECT
                ano,
                mes,
                codcli,
                MAX(cliente_nome) as cliente_nome,
                MAX(bairro) as bairro,
                MAX(cidade) as cidade,
                rede,
                SUM(faturamento) as faturamento,
                SUM(peso) as peso,
                SUM(caixas) as caixas,
                SUM(perda_valor) as perda_valor,
                SUM(bonificacao_valor) as bonificacao_valor,
                MAX(positivado) as clientes_positivados,
                SUM(inovou) as clientes_inovacoes
            FROM base_data
            GROUP BY 1, 2, 3, 7
        )
        SELECT COALESCE(json_agg(row_to_json(t)), ''[]''::json)
        FROM (
            SELECT * FROM monthly_agg ORDER BY ano DESC, mes DESC
        ) t
    ', v_where, v_where);

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$$;
