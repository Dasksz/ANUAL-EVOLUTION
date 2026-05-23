-- Migration: Fix JBP Innovations Count to use Categories instead of Pedidos
-- Description: The main table was counting distinct orders (pedido) instead of distinct categories.

CREATE OR REPLACE FUNCTION public.get_jbp_data(
    p_filial text[] DEFAULT NULL,
    p_cidade text[] DEFAULT NULL,
    p_supervisor text[] DEFAULT NULL,
    p_vendedor text[] DEFAULT NULL,
    p_fornecedor text[] DEFAULT NULL,
    p_rede text[] DEFAULT NULL,
    p_produto text[] DEFAULT NULL,
    p_categoria text[] DEFAULT NULL,
    p_categoria_inovacao text DEFAULT NULL,
    p_ano text DEFAULT NULL,
    p_clientes text[] DEFAULT NULL,
    p_redes_adicionadas text[] DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_where text := ' WHERE 1=1 ';
    v_where_inov text := '';
    v_rede_condition text := '';

    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];

    v_result json;
    v_sql text;

    v_trend_allowed boolean := false;
    v_trend_factor numeric := 1.0;
    v_work_days_passed integer;
    v_work_days_total integer;
    v_current_year integer := EXTRACT(YEAR FROM CURRENT_DATE)::int;
    v_month_start date;
    v_month_end date;
    v_max_sale_date date;
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Build Base Filters (alias 's' for data_detailed/history)
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        v_where := v_where || format(' AND EXTRACT(YEAR FROM s.dtped)::int IN (%s, %s) ', p_ano::int, p_ano::int - 1);
    ELSE
        v_where := v_where || format(' AND EXTRACT(YEAR FROM s.dtped)::int IN (EXTRACT(YEAR FROM CURRENT_DATE)::int, EXTRACT(YEAR FROM CURRENT_DATE)::int - 1) ');
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
        v_where := v_where || format(' AND s.produto IN (SELECT codigo FROM public.data_innovations WHERE inovacoes = %L) ', p_categoria_inovacao);
    END IF;

    -- Calculate Trends
    SELECT MAX(dtped) INTO v_max_sale_date FROM (
        SELECT MAX(dtped) as dtped FROM public.data_history
        UNION ALL
        SELECT MAX(dtped) as dtped FROM public.data_detailed
    );
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

    -- Dynamic SQL: Union of detailed and history
    -- Fix for MIX PDV: We fetch raw data directly and aggregate it by client/month,
    -- ensuring we distinct count the product correctly.
    v_sql := format('
        WITH inovacoes AS (
            SELECT DISTINCT inovacoes FROM public.data_innovations WHERE inovacoes IS NOT NULL %s
        ),
        raw_data AS (
            SELECT
                EXTRACT(YEAR FROM s.dtped)::int as ano,
                EXTRACT(MONTH FROM s.dtped)::int as mes,
                c.codigo_cliente as codcli,
                c.razaosocial as cliente_nome,
                c.bairro as bairro,
                c.cidade as cidade,
                c.ramo as rede,
                s.tipovenda,
                s.vlvenda,
                s.totpesoliq,
                s.qtvenda, dp.qtde_embalagem_master,
                s.vldevolucao,
                s.vlbonific,
                s.produto,
                s.pedido
            FROM public.data_detailed s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s
            UNION ALL
            SELECT
                EXTRACT(YEAR FROM s.dtped)::int as ano,
                EXTRACT(MONTH FROM s.dtped)::int as mes,
                c.codigo_cliente as codcli,
                c.razaosocial as cliente_nome,
                c.bairro as bairro,
                c.cidade as cidade,
                c.ramo as rede,
                s.tipovenda,
                s.vlvenda,
                s.totpesoliq,
                s.qtvenda, dp.qtde_embalagem_master,
                s.vldevolucao,
                s.vlbonific,
                s.produto,
                s.pedido
            FROM public.data_history s
            JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s
        ),
        base_data AS (
            SELECT
                ano,
                mes,
                codcli,
                MAX(cliente_nome) as cliente_nome,
                MAX(bairro) as bairro,
                MAX(cidade) as cidade,
                MAX(rede) as rede,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN COALESCE(vlvenda, 0) ELSE 0 END) as faturamento,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN COALESCE(totpesoliq, 0) ELSE 0 END) as peso,
                SUM(CASE WHEN tipovenda NOT IN (''5'', ''11'') THEN COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1) ELSE 0 END) as caixas,
                SUM(CASE WHEN tipovenda = ''5'' THEN COALESCE(vlvenda,0) + COALESCE(vldevolucao,0) + COALESCE(vlbonific,0) ELSE 0 END) as perda_valor,
                SUM(CASE WHEN tipovenda = ''11'' THEN COALESCE(vlvenda,0) + COALESCE(vlbonific,0) ELSE 0 END) as bonificacao_valor,
                MAX(CASE WHEN tipovenda NOT IN (''5'', ''11'') AND COALESCE(vlvenda,0) >= 1 THEN 1 ELSE 0 END) as positivado,
                COUNT(DISTINCT CASE WHEN tipovenda NOT IN (''5'', ''11'') AND produto IN (SELECT DISTINCT codigo FROM public.data_innovations WHERE inovacoes IS NOT NULL) AND COALESCE(vlvenda, 0) >= 1 THEN (SELECT max(inovacoes) FROM public.data_innovations d_in WHERE d_in.codigo = raw_data.produto) ELSE NULL END) as inovou,
                COUNT(DISTINCT CASE WHEN tipovenda IN (''1'', ''9'') AND COALESCE(vlvenda,0) >= 1 THEN produto ELSE NULL END) as pre_mix_count
            FROM raw_data
            GROUP BY 1, 2, 3
        ),
        monthly_agg AS (
            SELECT
                ano,
                mes,
                codcli,
                MAX(cliente_nome) as cliente_nome,
                MAX(bairro) as bairro,
                MAX(cidade) as cidade,
                MAX(rede) as rede,
                SUM(faturamento) as faturamento,
                SUM(peso) as peso,
                SUM(caixas) as caixas,
                SUM(perda_valor) as perda_valor,
                SUM(bonificacao_valor) as bonificacao_valor,
                MAX(positivado) as clientes_positivados,
                SUM(inovou) as clientes_inovacoes,
                MAX(pre_mix_count) as total_mix
            FROM base_data
            GROUP BY 1, 2, 3
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
    ', v_where_inov, v_where, v_where, v_trend_allowed, v_trend_factor, COALESCE(EXTRACT(MONTH FROM v_max_sale_date)::int - 1, 11));

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$function$;