CREATE OR REPLACE FUNCTION public.get_city_positivity_table(
    p_ano text,
    p_quarter int,
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_magic_number numeric;
    v_mes_1 text;
    v_mes_2 text;
    v_mes_3 text;
    v_where text := ' WHERE 1=1 ';
    v_where_base_cidades text := ' WHERE 1=1 ';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
    v_sql text;
    v_result json;
    v_has_filters boolean := false;
BEGIN
    SELECT magic_number INTO v_magic_number FROM public.config_magic_number LIMIT 1;
    IF v_magic_number IS NULL OR v_magic_number = 0 THEN
        v_magic_number := 700;
    END IF;

    IF p_quarter = 1 THEN
        v_mes_1 := '01'; v_mes_2 := '02'; v_mes_3 := '03';
    ELSIF p_quarter = 2 THEN
        v_mes_1 := '04'; v_mes_2 := '05'; v_mes_3 := '06';
    ELSIF p_quarter = 3 THEN
        v_mes_1 := '07'; v_mes_2 := '08'; v_mes_3 := '09';
    ELSE
        v_mes_1 := '10'; v_mes_2 := '11'; v_mes_3 := '12';
    END IF;

    -- Dynamic Filters (applied to both queries)
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_where := v_where || format(' AND ds.ano = %L ', p_ano);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.ano = %L ', p_ano);
    END IF;

    -- Base filters
    v_where := v_where || ' AND ds.tipovenda NOT IN (''5'', ''11'') ';
    v_where_base_cidades := v_where_base_cidades || ' AND ds.tipovenda NOT IN (''5'', ''11'') ';

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND ds.filial = ANY(%L) ', p_filial);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.filial = ANY(%L) ', p_filial);
        v_has_filters := true;
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND dc.cidade = ANY(%L) ', p_cidade);
        v_where_base_cidades := v_where_base_cidades || format(' AND dc.cidade = ANY(%L) ', p_cidade);
        v_has_filters := true;
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
        v_has_filters := true;
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
        v_has_filters := true;
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND ds.codfor = ANY(%L) ', p_fornecedor);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.codfor = ANY(%L) ', p_fornecedor);
        v_has_filters := true;
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND ds.tipovenda = ANY(%L) ', p_tipovenda);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.tipovenda = ANY(%L) ', p_tipovenda);
        v_has_filters := true;
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND ds.categoria_produto = ANY(%L) ', p_categoria);
        v_where_base_cidades := v_where_base_cidades || format(' AND ds.categoria_produto = ANY(%L) ', p_categoria);
        v_has_filters := true;
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
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
           v_where_base_cidades := v_where_base_cidades || ' AND (' || v_rede_condition || ') ';
       END IF;
       v_has_filters := true;
    END IF;

    -- Add Quarter month filters ONLY to v_where
    v_where := v_where || format(' AND ds.mes IN (%L, %L, %L) ', v_mes_1, v_mes_2, v_mes_3);

    v_sql := '
        WITH base_cidades AS (
            SELECT cb.cidade, COALESCE(cb.population, 0) as population
            FROM public.config_city_branches cb
            ' || CASE WHEN v_has_filters THEN '
            WHERE cb.cidade IN (
                SELECT DISTINCT dc.cidade
                FROM public.data_summary ds
                JOIN public.data_clients dc ON ds.codcli = dc.codigo_cliente
                ' || v_where_base_cidades || '
            )
            ' ELSE '' END || '
        ),
        base_vendas AS (
            SELECT
                dc.cidade,
                ds.mes,
                ds.codcli
            FROM public.data_summary ds
            JOIN public.data_clients dc ON ds.codcli = dc.codigo_cliente
            ' || v_where || '
            GROUP BY dc.cidade, ds.mes, ds.codcli
            HAVING SUM(ds.vlvenda) >= 1
        ),
        pos_por_cidade_mes AS (
            SELECT
                cidade,
                mes,
                COUNT(DISTINCT codcli) as pos
            FROM base_vendas
            GROUP BY cidade, mes
        ),
        pos_acumulada_por_cidade AS (
            SELECT
                cidade,
                COUNT(DISTINCT codcli) as acm
            FROM base_vendas
            GROUP BY cidade
        )
        SELECT COALESCE(json_agg(row_to_json(final_data)), ''[]''::json)
        FROM (
            SELECT
                bc.cidade,
                bc.population,
                ' || v_magic_number || ' as magic_number_divisor,
                CASE WHEN bc.population > 0 THEN ROUND(bc.population / ' || v_magic_number || ') ELSE 0 END as magic_number,
                COALESCE(acm.acm, 0) as acm,
                COALESCE(MAX(CASE WHEN pos.mes = ''' || v_mes_1 || ''' THEN pos.pos ELSE 0 END), 0) as m1_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''' || v_mes_2 || ''' THEN pos.pos ELSE 0 END), 0) as m2_pos,
                COALESCE(MAX(CASE WHEN pos.mes = ''' || v_mes_3 || ''' THEN pos.pos ELSE 0 END), 0) as m3_pos
            FROM base_cidades bc
            LEFT JOIN pos_por_cidade_mes pos ON bc.cidade = pos.cidade
            LEFT JOIN pos_acumulada_por_cidade acm ON bc.cidade = acm.cidade
            GROUP BY bc.cidade, bc.population, acm.acm
            ORDER BY bc.cidade
        ) final_data;
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;
