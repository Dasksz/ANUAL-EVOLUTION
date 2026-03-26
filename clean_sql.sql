CREATE OR REPLACE FUNCTION get_mix_salty_foods_data(
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
    v_target_month int;
    v_where_chart text := ' WHERE 1=1 ';
    v_where_rede text := '';
    v_sql text;
    v_result json;

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary_frequency;
    ELSE
        v_current_year := p_ano::int;
    END IF;

    v_where_chart := v_where_chart || ' AND s.dtped >= make_date(' || v_current_year || ', 1, 1) AND s.dtped <= make_date(' || v_current_year || ', 12, 31) ';

    -- 2. Build Where Clauses
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_chart := v_where_chart || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codcli IN (SELECT codigo_cliente FROM public.data_clients WHERE cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || '''])) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            v_where_chart := v_where_chart || ' AND s.codfor = ANY(ARRAY[''' || array_to_string(p_fornecedor, ''',''') || ''']) ';
        END IF;
    END IF;

    -- REDE Logic (same as comparativo)
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('c.ramo = ANY(ARRAY[''%s''])', array_to_string(v_specific_redes, ''','''));
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
           v_where_rede := ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.produto = ANY(ARRAY[''' || array_to_string(p_produto, ''',''') || ''']) ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND dp.categoria_produto = ANY(ARRAY[''' || array_to_string(p_categoria, ''',''') || ''']) ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    -- Dynamic Query using the exact same logic from get_comparison_view_data
    v_sql := '
    WITH all_sales AS (
        SELECT s.dtped, s.vlvenda, s.codcli, s.produto, dp.mix_marca, dp.mix_categoria, s.codfor
        FROM public.data_detailed s
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
        ' || v_where_chart || v_where_rede || '
        UNION ALL
        SELECT s.dtped, s.vlvenda, s.codcli, s.produto, dp.mix_marca, dp.mix_categoria, s.codfor
        FROM public.data_history s
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
        ' || v_where_chart || v_where_rede || '
    ),
    prod_agg AS (
        SELECT
            EXTRACT(MONTH FROM dtped)::int as mes,
            codcli,
            produto,
            MAX(mix_marca) as mix_marca,
            MAX(mix_categoria) as mix_cat,
            MAX(codfor) as codfor,
            SUM(vlvenda) as prod_val
        FROM all_sales
        GROUP BY 1, 2, 3
    ),
    monthly_mix AS (
        SELECT
            mes,
            codcli,
            SUM(prod_val) as total_val,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''CHEETOS'' THEN 1 ELSE 0 END) as has_cheetos,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''DORITOS'' THEN 1 ELSE 0 END) as has_doritos,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''FANDANGOS'' THEN 1 ELSE 0 END) as has_fandangos,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''RUFFLES'' THEN 1 ELSE 0 END) as has_ruffles,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TORCIDA'' THEN 1 ELSE 0 END) as has_torcida,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDYNHO'' THEN 1 ELSE 0 END) as has_toddynho,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDY'' THEN 1 ELSE 0 END) as has_toddy,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''QUAKER'' THEN 1 ELSE 0 END) as has_quaker,
            MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''KEROCOCO'' THEN 1 ELSE 0 END) as has_kerococo
        FROM prod_agg
        GROUP BY 1, 2
    ),
    monthly_flags AS (
        SELECT
            mes,
            codcli,
            (has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1) as is_salty,
            (has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1) as is_foods
        FROM monthly_mix
    ),
    chart_data AS (
        SELECT
            ' || v_current_year || ' as ano,
            mes,
            COUNT(DISTINCT CASE WHEN is_salty THEN codcli END) as total_salty,
            COUNT(DISTINCT CASE WHEN is_foods THEN codcli END) as total_foods,
            COUNT(DISTINCT CASE WHEN is_salty AND is_foods THEN codcli END) as total_ambas
        FROM monthly_flags
        GROUP BY mes
        ORDER BY mes
    )
    SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data;
    ';

    EXECUTE v_sql INTO v_result;

    RETURN json_build_object(
        'chart_data', v_result,
        'current_year', v_current_year
    );
END;
$$;
