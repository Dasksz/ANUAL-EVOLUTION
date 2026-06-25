CREATE OR REPLACE FUNCTION public.get_city_segmentation_positivity_table(
    p_ano text,
    p_mes text,
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_tipovenda text[] default null,
    p_segmentacao text[] default null,
    p_rede text[] default null,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_where text := ' WHERE ds.tipovenda IN (''1'', ''9'') ';
    v_where_acumulado text;
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
    v_sql text;
    v_result json;
    v_target_month integer;
BEGIN
    -- Dynamic Filters
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_where := v_where || format(' AND ds.ano = %L ', p_ano);
    ELSE
        v_where := v_where || format(' AND ds.ano = %L ', extract(year from current_date)::text);
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' THEN
        v_target_month := p_mes::int;
    ELSE
        v_target_month := 12;
    END IF;

    -- For accumulated metric, we bound the months up to the selected target month.
    -- The month condition will be applied per metric or bounded generally and then filtered by month in CASE WHEN.
    v_where_acumulado := v_where || format(' AND ds.mes::int <= %L ', v_target_month);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND dc.cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND ds.categoria_produto = ANY(%L) ', p_categoria);
    END IF;
    IF p_segmentacao IS NOT NULL AND array_length(p_segmentacao, 1) > 0 THEN
        v_where_acumulado := v_where_acumulado || format(' AND dc.ramo_atividade = ANY(%L) ', p_segmentacao);
    END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('UPPER(dc.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x))', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (dc.ramo IS NOT NULL AND dc.ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (dc.ramo IS NULL OR dc.ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_acumulado := v_where_acumulado || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    v_sql := '
        WITH base_vendas AS (
            SELECT
                COALESCE(dc.ramo_atividade, ''OUTROS'') as segmentacao,
                ds.mes,
                ds.codcli
            FROM public.data_summary ds
            JOIN public.data_clients dc ON ds.codcli = dc.codigo_cliente
            ' || v_where_acumulado || '
            GROUP BY COALESCE(dc.ramo_atividade, ''OUTROS''), ds.mes, ds.codcli
            HAVING SUM(ds.vlvenda) >= 1
        ),
        pos_por_segmentacao_mes AS (
            SELECT
                segmentacao,
                mes,
                COUNT(DISTINCT codcli) as pos
            FROM base_vendas
            GROUP BY segmentacao, mes
        ),
        acumulado_segmentacao AS (
            SELECT
                segmentacao,
                COUNT(DISTINCT codcli) as pos_acumulado
            FROM base_vendas
            GROUP BY segmentacao
        )
        SELECT COALESCE(json_agg(row_to_json(final_data)), ''[]''::json)
        FROM (
            SELECT
                ac.segmentacao,
                COALESCE(ac.pos_acumulado, 0) as pos_acumulado,
                COALESCE(MAX(CASE WHEN pos.mes = ''01'' THEN pos.pos ELSE 0 END), 0) as m1_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''02'' THEN pos.pos ELSE 0 END), 0) as m2_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''03'' THEN pos.pos ELSE 0 END), 0) as m3_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''04'' THEN pos.pos ELSE 0 END), 0) as m4_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''05'' THEN pos.pos ELSE 0 END), 0) as m5_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''06'' THEN pos.pos ELSE 0 END), 0) as m6_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''07'' THEN pos.pos ELSE 0 END), 0) as m7_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''08'' THEN pos.pos ELSE 0 END), 0) as m8_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''09'' THEN pos.pos ELSE 0 END), 0) as m9_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''10'' THEN pos.pos ELSE 0 END), 0) as m10_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''11'' THEN pos.pos ELSE 0 END), 0) as m11_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''12'' THEN pos.pos ELSE 0 END), 0) as m12_pos
            FROM acumulado_segmentacao ac
            LEFT JOIN pos_por_segmentacao_mes pos ON ac.segmentacao = pos.segmentacao
            GROUP BY ac.segmentacao, ac.pos_acumulado
            ORDER BY ac.pos_acumulado DESC, ac.segmentacao
        ) final_data;
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;
