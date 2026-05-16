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

    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';

    v_result json;
    v_sql text;
BEGIN
    -- Security Check
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL statement_timeout = '600s';

    -- Build Base Filters
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_where := v_where || format(' AND ds.ano IN (%s, %s) ', p_ano::int, p_ano::int - 1);
    ELSE
        v_where := v_where || format(' AND ds.ano IN (EXTRACT(YEAR FROM CURRENT_DATE)::int, EXTRACT(YEAR FROM CURRENT_DATE)::int - 1) ');
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND ds.filial = ANY(%L::text[]) ', p_filial);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND ds.cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codsupervisor = ANY(%L::text[]) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codusur = ANY(%L::text[]) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codfor = ANY(%L::text[]) ', p_fornecedor);
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where := v_where || format(' AND EXISTS (SELECT 1 FROM unnest(ds.produtos_arr) p WHERE p = ANY(%L::text[])) ', p_produto);
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND EXISTS (SELECT 1 FROM unnest(ds.categorias_arr) c WHERE c = ANY(%L::text[])) ', p_categoria);
    END IF;

    -- REDE Logic (from general filters)
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('ds.rede = ANY(%L)', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ds.rede IS NOT NULL AND ds.rede NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ds.rede IS NULL OR ds.rede IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- JBP Specific filtering: must match the specific clients OR redes we are adding to the panel
    IF (p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0) OR (p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0) THEN
        v_where := v_where || ' AND (';

        IF p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0 THEN
            v_where := v_where || format(' ds.codcli = ANY(%L::text[]) ', p_clientes);
        ELSE
            v_where := v_where || ' 1=0 ';
        END IF;

        IF p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0 THEN
            v_where := v_where || format(' OR ds.rede = ANY(%L::text[]) ', p_redes_adicionadas);
        END IF;

        v_where := v_where || ') ';
    END IF;

    -- Dynamic SQL: Using data_summary_frequency for consistency and better performance, just like the dashboard does
    v_sql := format('
        WITH inovacoes AS (
            SELECT codigo FROM public.data_innovations WHERE codigo IS NOT NULL
        ),
        base_data AS (
            SELECT
                ds.ano,
                ds.mes,
                ds.codcli,
                MAX(dc.razaosocial) as cliente_nome,
                ds.rede,
                SUM(CASE WHEN ds.tipovenda NOT IN (''5'', ''11'') THEN ds.vlvenda ELSE 0 END) as faturamento,
                SUM(CASE WHEN ds.tipovenda NOT IN (''5'', ''11'') THEN ds.peso ELSE 0 END) as peso,
                SUM(CASE WHEN ds.tipovenda NOT IN (''5'', ''11'') THEN ds.caixas ELSE 0 END) as caixas,
                SUM(CASE WHEN ds.tipovenda = ''5'' THEN ds.vlvenda + COALESCE(ds.devolucao,0) + COALESCE(ds.bonificacao,0) ELSE 0 END) as perda_valor,
                SUM(CASE WHEN ds.tipovenda = ''11'' THEN ds.vlvenda + COALESCE(ds.bonificacao,0) ELSE 0 END) as bonificacao_valor,
                MAX(CASE WHEN ds.tipovenda NOT IN (''5'', ''11'') AND ds.vlvenda > 0 THEN 1 ELSE 0 END) as positivado,
                COUNT(DISTINCT CASE WHEN ds.produtos_arr && ARRAY(SELECT codigo FROM inovacoes) AND ds.tipovenda NOT IN (''5'', ''11'') THEN ds.codcli ELSE NULL END) as inovou
            FROM public.data_summary_frequency ds
            LEFT JOIN public.data_clients dc ON ds.codcli = dc.codigo_cliente
            %s
            GROUP BY 1, 2, 3, 5
        ),
        monthly_agg AS (
            SELECT
                ano,
                mes,
                codcli,
                MAX(cliente_nome) as cliente_nome,
                rede,
                SUM(faturamento) as faturamento,
                SUM(peso) as peso,
                SUM(caixas) as caixas,
                SUM(perda_valor) as perda_valor,
                SUM(bonificacao_valor) as bonificacao_valor,
                SUM(positivado) as clientes_positivados,
                SUM(inovou) as clientes_inovacoes
            FROM base_data
            GROUP BY 1, 2, 3, 5
        )
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT * FROM monthly_agg ORDER BY ano DESC, mes DESC, faturamento DESC
        ) t
    ', v_where);

    EXECUTE v_sql INTO v_result;

    RETURN COALESCE(v_result, '[]'::json);
END;
$$;
