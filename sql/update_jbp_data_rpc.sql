CREATE OR REPLACE FUNCTION get_jbp_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
    p_categoria text[] default null,
    p_categoria_inovacao text default null,
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
    v_where_inov text := '';

    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';

    v_mix_constraint text;

    -- Trend Variables
    v_max_sale_date date;
    v_current_year int;
    v_trend_allowed boolean;
    v_work_days_passed int;
    v_work_days_total int;
    v_trend_factor numeric := 1;
    v_month_start date;
    v_month_end date;

    v_result json;
    v_sql text;
BEGIN
    -- Security Check
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL statement_timeout = '600s';

    -- 1. Determine Date Range and Trend Factor
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_current_year := p_ano::int;
        v_where := v_where || format(' AND EXTRACT(YEAR FROM s.dtped)::int IN (%s, %s) ', p_ano::int, p_ano::int - 1);
    ELSE
        v_current_year := EXTRACT(YEAR FROM CURRENT_DATE)::int;
        v_where := v_where || format(' AND EXTRACT(YEAR FROM s.dtped)::int IN (%s, %s) ', v_current_year, v_current_year - 1);
    END IF;

    -- Trend Logic
    v_max_sale_date := (SELECT MAX(dtped)::date FROM public.data_detailed);
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);

    IF v_trend_allowed THEN
        v_month_start := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        END IF;
    END IF;


    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND COALESCE(s.cidade, c.cidade) = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND s.codsupervisor = ANY(%L::text[]) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND s.codusur = ANY(%L::text[]) ', p_vendedor);
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

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('c.ramo = ANY(%L)', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NOT NULL AND c.ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NULL OR c.ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;


    -- JBP Specific filtering: must match the specific clients OR redes we are adding to the panel
    IF (p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0) OR (p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0) THEN
        v_where := v_where || ' AND (';

        IF p_clientes IS NOT NULL AND array_length(p_clientes, 1) > 0 THEN
            v_where := v_where || format(' c.codigo_cliente = ANY(%L::text[]) ', p_clientes);
        ELSE
            v_where := v_where || ' 1=0 ';
        END IF;

        IF p_redes_adicionadas IS NOT NULL AND array_length(p_redes_adicionadas, 1) > 0 THEN
            v_where := v_where || format(' OR c.ramo = ANY(%L::text[]) ', p_redes_adicionadas);
        END IF;

        v_where := v_where || ') ';
    END IF;

    -- JBP Categoria Inovacao Filtering
    IF p_categoria_inovacao IS NOT NULL AND p_categoria_inovacao != '' THEN
        v_where_inov := format(' AND inovacoes = %L ', p_categoria_inovacao);
        -- Also enforce that the main query only considers products in this specific innovation category
        v_where := v_where || format(' AND s.produto IN (SELECT codigo FROM public.data_innovations WHERE inovacoes = %L) ', p_categoria_inovacao);
    END IF;

    -- MIX Constraint Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_mix_constraint := ' 1=1 ';
    ELSE
        v_mix_constraint := ' s.codfor IN (''707'', ''708'', ''752'') ';
    END IF;


    -- Dynamic SQL: Union of detailed and history
    v_sql := format('
        WITH inovacoes AS (
            SELECT DISTINCT inovacoes FROM public.data_innovations WHERE inovacoes IS NOT NULL %s
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
                COUNT(DISTINCT CASE WHEN inov.inovacoes IS NOT NULL AND COALESCE(s.vlvenda, 0) >= 1 THEN inov.inovacoes ELSE NULL END) as inovacao_pedidos,
                COUNT(DISTINCT CASE WHEN s.tipovenda IN (''1'', ''9'') AND (%s) THEN s.produto ELSE NULL END) as atingiu_mix
            FROM public.data_detailed s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            LEFT JOIN public.data_innovations inov ON s.produto = inov.codigo
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
                COUNT(DISTINCT CASE WHEN inov.inovacoes IS NOT NULL AND COALESCE(s.vlvenda, 0) >= 1 THEN inov.inovacoes ELSE NULL END) as inovacao_pedidos,
                COUNT(DISTINCT CASE WHEN s.tipovenda IN (''1'', ''9'') AND (%s) THEN s.produto ELSE NULL END) as atingiu_mix
            FROM public.data_history s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            LEFT JOIN public.data_innovations inov ON s.produto = inov.codigo
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
                MAX(CASE WHEN tipovenda NOT IN (''5'', ''11'') AND inovacao_pedidos > 0 THEN inovacao_pedidos ELSE 0 END) as inovou,
                SUM(atingiu_mix) as pre_mix_count
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
                MAX(inovou) as clientes_inovacoes,
                SUM(pre_mix_count) as total_mix
            FROM base_data
            GROUP BY 1, 2, 3, 7
        )
        SELECT json_build_object(
            ''data'', COALESCE(json_agg(row_to_json(t)), ''[]''::json),
            ''trend_allowed'', %L,
            ''trend_factor'', %s,
            ''trend_month_index'', %s
        )
        FROM (
            SELECT * FROM monthly_agg ORDER BY ano DESC, mes DESC
        ) t
    ', v_where_inov, v_mix_constraint, v_where, v_mix_constraint, v_where, v_trend_allowed, v_trend_factor, COALESCE(EXTRACT(MONTH FROM v_max_sale_date)::int - 1, 11));

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$$;
