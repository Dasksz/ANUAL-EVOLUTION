-- 1. Create the new summary table
CREATE TABLE IF NOT EXISTS public.data_summary_produtos (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    ano integer,
    mes integer,
    filial text,
    cidade text,
    codsupervisor text,
    codusur text,
    codfor text,
    tipovenda text,
    codcli text,
    ramo text,
    categoria_produto text,
    produto text,
    vlvenda numeric DEFAULT 0,
    peso numeric DEFAULT 0,
    caixas numeric DEFAULT 0
);
ALTER TABLE public.data_summary_produtos ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_data_summary_prod_ano_mes ON public.data_summary_produtos(ano, mes);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_produto ON public.data_summary_produtos(produto);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_cat ON public.data_summary_produtos(categoria_produto);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_codcli ON public.data_summary_produtos(codcli);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_filial ON public.data_summary_produtos(filial);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_codfor ON public.data_summary_produtos(codfor);
CREATE INDEX IF NOT EXISTS idx_data_summary_prod_tipovenda ON public.data_summary_produtos(tipovenda);

-- Populate the table with existing data (this might take a minute)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.data_summary_produtos LIMIT 1) THEN
        RAISE NOTICE 'Populating data_summary_produtos with initial data...';

        -- Insert from Detailed and History combined to avoid massive memory issues in one go.
        -- Using smaller batches or just a straightforward insert if memory allows.
        -- In this case, we'll do it all via INSERT INTO SELECT.
        INSERT INTO public.data_summary_produtos (
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto, vlvenda, peso, caixas
        )
        WITH dim_prod_enhanced AS (
            SELECT
                codigo,
                categoria_produto,
                qtde_embalagem_master,
                CASE
                    WHEN descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                    WHEN descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                    WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                    WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                    ELSE '1119_OUTROS'
                END as codfor_enhanced
            FROM public.dim_produtos
        ),
        raw_combined AS (
            SELECT EXTRACT(YEAR FROM dtped)::int as ano, EXTRACT(MONTH FROM dtped)::int as mes,
                   filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, produto, qtvenda
            FROM public.data_detailed
            UNION ALL
            SELECT EXTRACT(YEAR FROM dtped)::int as ano, EXTRACT(MONTH FROM dtped)::int as mes,
                   filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, produto, qtvenda
            FROM public.data_history
        ),
        augmented_data AS (
            SELECT
                r.ano, r.mes, r.filial, COALESCE(r.cidade, c.cidade) as cidade, r.codsupervisor, r.codusur,
                CASE
                    WHEN r.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
                    ELSE r.codfor
                END as codfor,
                r.tipovenda, r.codcli, c.ramo, dp.categoria_produto, r.produto,
                r.vlvenda, r.totpesoliq, r.qtvenda, dp.qtde_embalagem_master
            FROM raw_combined r
            LEFT JOIN public.data_clients c ON r.codcli = c.codigo_cliente
            LEFT JOIN dim_prod_enhanced dp ON r.produto = dp.codigo
        )
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
            SUM(vlvenda) as vlvenda,
            SUM(totpesoliq) as peso,
            SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12;
    END IF;
END $$;

-- 2. Update refresh_summary_chunk function to also populate data_summary_produtos
CREATE OR REPLACE FUNCTION refresh_summary_chunk(p_start_date date, p_end_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year int;
    v_month int;
BEGIN
    SET LOCAL statement_timeout = '1800s'; -- Increased to 30 mins to avoid immediate API cutoff
    SET LOCAL work_mem = '256MB'; -- More memory for internal hashing during grouped inserts

    v_year := EXTRACT(YEAR FROM p_start_date);
    v_month := EXTRACT(MONTH FROM p_start_date);

    -- STEP A: Create a temporary table for the raw data of the month to avoid massive UNION ALL memory plans
    CREATE TEMP TABLE tmp_raw_data ON COMMIT DROP AS
    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
    FROM public.data_detailed
    WHERE dtped >= p_start_date AND dtped < p_end_date
    UNION ALL
    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
    FROM public.data_history
    WHERE dtped >= p_start_date AND dtped < p_end_date;

    CREATE INDEX idx_tmp_raw_produto ON tmp_raw_data(produto);
    CREATE INDEX idx_tmp_raw_codcli ON tmp_raw_data(codcli);
    CREATE INDEX idx_tmp_raw_pedido ON tmp_raw_data(pedido);

    -- Common CTEs for enrichment
    CREATE TEMP TABLE tmp_dim_prod_enhanced ON COMMIT DROP AS
    SELECT
        codigo,
        categoria_produto,
        mix_marca,
        qtde_embalagem_master,
        CASE
            WHEN descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
            WHEN descricao ILIKE '%TODDY %' THEN '1119_TODDY'
            WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
            WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
            ELSE '1119_OUTROS'
        END as codfor_enhanced
    FROM public.dim_produtos;

    CREATE INDEX idx_tmp_dim_prod_codigo ON tmp_dim_prod_enhanced(codigo);

    -- STEP B1: Prepare augmented data
    CREATE TEMP TABLE tmp_augmented_data ON COMMIT DROP AS
    SELECT
        v_year as ano,
        v_month as mes,
        CASE
            WHEN s.codcli = '11625' AND v_year = 2025 AND v_month = 12 THEN '05'
            ELSE s.filial
        END as filial,
        COALESCE(s.cidade, c.cidade) as cidade,
        s.codsupervisor,
        s.codusur,
        CASE
            WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
            ELSE s.codfor
        END as codfor,
        s.tipovenda,
        s.codcli,
        s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda, dp.qtde_embalagem_master,
        c.ramo,
        dp.categoria_produto,
        dp.mix_marca,
        s.pedido
    FROM tmp_raw_data s
    LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
    LEFT JOIN tmp_dim_prod_enhanced dp ON s.produto = dp.codigo;

    -- STEP B2: Aggregate by Product (Base for multiple other tables)
    CREATE TEMP TABLE tmp_product_agg ON COMMIT DROP AS
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto, mix_marca, pedido,
        SUM(vlvenda) as prod_val,
        SUM(totpesoliq) as prod_peso,
        SUM(vlbonific) as prod_bonific,
        SUM(COALESCE(vldevolucao, 0)) as prod_devol,
        SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as prod_caixas
    FROM tmp_augmented_data
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14;

    -- Delete old records in data_summary for the chunk month to prevent duplicates if chunk is retried
    DELETE FROM public.data_summary WHERE ano = v_year AND mes = v_month;

    -- STEP B3: Insert into data_summary
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto, cnpj
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        SUM(prod_val) as total_val,
        SUM(prod_peso) as total_peso,
        SUM(prod_bonific) as total_bonific,
        SUM(prod_devol) as total_devol,
        COUNT(CASE WHEN prod_val >= 1 THEN 1 END) as mix_calc,
        CASE WHEN SUM(prod_val) >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        SUM(prod_caixas) as total_caixas,
        categoria_produto,
        NULL::text as cnpj
    FROM tmp_product_agg
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto;

    -- Delete old records in data_summary_produtos
    DELETE FROM public.data_summary_produtos WHERE ano = v_year AND mes = v_month;

    -- NEW STEP B4: Insert into data_summary_produtos
    INSERT INTO public.data_summary_produtos (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto, vlvenda, peso, caixas
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
        SUM(prod_val) as vlvenda,
        SUM(prod_peso) as peso,
        SUM(prod_caixas) as caixas
    FROM tmp_product_agg
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto;

    -- Delete old records in data_summary_frequency
    DELETE FROM public.data_summary_frequency WHERE ano = v_year AND mes = v_month;

    -- STEP C: Insert into data_summary_frequency
    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo, cnpj
    )
    SELECT
        ano,
        mes,
        filial,
        cidade,
        codsupervisor,
        codusur,
        codfor,
        codcli,
        tipovenda,
        pedido,
        SUM(prod_val) as vlvenda,
        SUM(prod_peso) as peso,
        jsonb_agg(DISTINCT produto) as produtos,
        jsonb_agg(DISTINCT categoria_produto) FILTER (WHERE categoria_produto IS NOT NULL) as categorias,
        NULL::text as rede,
        array_agg(DISTINCT produto) as produtos_arr,
        array_agg(DISTINCT categoria_produto) FILTER (WHERE categoria_produto IS NOT NULL) as categorias_arr,
        MAX(CASE WHEN mix_marca = 'CHEETOS' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_cheetos,
        MAX(CASE WHEN mix_marca = 'DORITOS' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_doritos,
        MAX(CASE WHEN mix_marca = 'FANDANGOS' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_fandangos,
        MAX(CASE WHEN mix_marca = 'RUFFLES' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_ruffles,
        MAX(CASE WHEN mix_marca = 'TORCIDA' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_torcida,
        MAX(CASE WHEN mix_marca = 'TODDYNHO' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_toddynho,
        MAX(CASE WHEN mix_marca = 'TODDY' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_toddy,
        MAX(CASE WHEN mix_marca = 'QUAKER' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_quaker,
        MAX(CASE WHEN mix_marca = 'KEROCOCO' AND prod_val >= 1 THEN 1 ELSE 0 END) as has_kerococo,
        NULL::text as cnpj
    FROM tmp_product_agg
    GROUP BY
        ano,
        mes,
        filial,
        cidade,
        codsupervisor,
        codusur,
        codfor,
        codcli,
        tipovenda,
        pedido;

END;
$$;

-- 3. Modify get_boxes_dashboard_data to use data_summary_produtos
CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(
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
    v_curr_year_start date;
    v_curr_year_end date;
    v_prev_year_start date;
    v_prev_year_end date;
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_eval_target_month int;
    v_ref_date date;
    v_tri_start date;
    v_tri_end date;

    v_where_summary text := ' WHERE 1=1 ';
    v_where_produtos text := ' WHERE 1=1 ';

    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];

    -- Tipovenda cond for clients
    v_tipovenda_client_cond text;
    v_active_client_cond text;

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_month_start date;
    v_month_end date;
    v_work_days_passed int;
    v_work_days_total int;
    v_curr_month_idx int;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '90MB';
    SET LOCAL statement_timeout = '600s';

    -- 1. Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary);
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    -- Define start and end dates based on year and month
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_ref_date := make_date(v_current_year, v_target_month, 1);
        v_curr_year_start := v_ref_date;
        v_curr_year_end := (v_curr_year_start + interval '1 month' - interval '1 day')::date;
        v_prev_year_start := make_date(v_previous_year, v_target_month, 1);
        v_prev_year_end := (v_prev_year_start + interval '1 month' - interval '1 day')::date;
    ELSE
        IF v_current_year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
            v_ref_date := make_date(v_current_year, 12, 1);
        ELSE
             v_ref_date := date_trunc('month', CURRENT_DATE)::date;
        END IF;
        v_curr_year_start := make_date(v_current_year, 1, 1);
        v_curr_year_end := make_date(v_current_year, 12, 31);
        v_prev_year_start := make_date(v_previous_year, 1, 1);
        v_prev_year_end := make_date(v_previous_year, 12, 31);
    END IF;

    v_tri_end := (v_ref_date - interval '1 day')::date;
    v_tri_start := (v_ref_date - interval '3 months')::date;

    -- Trend Logic Calculation
    v_max_sale_date := (SELECT MAX(dtped)::date FROM public.data_detailed);
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN
           v_trend_allowed := false;
       END IF;
    END IF;

    IF v_trend_allowed THEN
        v_month_start := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;
    END IF;

    -- 2. Build FILTERS
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_produtos := v_where_produtos || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND filial = ANY(%L) ', p_filial);
        v_where_produtos := v_where_produtos || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_produtos := v_where_produtos || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         v_where_summary := v_where_summary || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
         v_where_produtos := v_where_produtos || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_summary := v_where_summary || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
         v_where_produtos := v_where_produtos || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        v_where_produtos := v_where_produtos || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        v_tipovenda_client_cond := format('tipovenda = ANY(%L)', p_tipovenda);
        IF p_tipovenda <@ ARRAY['5','11'] THEN
            v_active_client_cond := format('tipovenda = ANY(%L) AND bonificacao > 0', p_tipovenda);
        ELSE
            v_active_client_cond := format('tipovenda = ANY(%L) AND tipovenda NOT IN (''5'', ''11'') AND pre_positivacao_val >= 1', p_tipovenda);
        END IF;
    ELSE
        v_tipovenda_client_cond := 'tipovenda IN (''1'', ''9'')';
        v_active_client_cond := 'tipovenda NOT IN (''5'', ''11'') AND pre_positivacao_val >= 1';
    END IF;

    -- Category Filter
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND categoria_produto = ANY(%L) ', p_categoria);
        v_where_produtos := v_where_produtos || format(' AND categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND codfor = ANY(%L) ', p_fornecedor);
        v_where_produtos := v_where_produtos || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('UPPER(ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x))', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NULL OR ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_summary := v_where_summary || ' AND (' || v_rede_condition || ') ';
           v_where_produtos := v_where_produtos || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- 3. Execute Queries using FAST PATH (data_summary & data_summary_produtos)

    EXECUTE format('
        WITH
        chart_agg AS (
            SELECT
                mes - 1 as m_idx,
                ano as yr,
                SUM(vlvenda) as fat,
                SUM(peso) as peso,
                SUM(COALESCE(caixas, 0)) as caixas,
                COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes
            FROM public.data_summary
            %s AND (ano = %L OR ano = %L)
            GROUP BY 1, 2
        ),
        kpi_curr AS (
            SELECT
                SUM(vlvenda) as fat,
                SUM(peso) as peso,
                SUM(COALESCE(caixas, 0)) as caixas,
                COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes
            FROM public.data_summary
            %s AND ano = %L %s
        ),
        kpi_prev AS (
            SELECT
                SUM(vlvenda) as fat,
                SUM(peso) as peso,
                SUM(COALESCE(caixas, 0)) as caixas,
                COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes
            FROM public.data_summary
            %s AND ano = %L %s
        ),
        kpi_tri AS (
            SELECT
                SUM(vlvenda) / 3 as fat,
                SUM(peso) / 3 as peso,
                SUM(COALESCE(caixas, 0)) / 3 as caixas,
                COALESCE((
                    SELECT SUM(monthly_clients) / 3
                    FROM (
                        SELECT COUNT(DISTINCT CASE WHEN %s THEN codcli END) as monthly_clients
                        FROM public.data_summary
                        %s AND make_date(ano, mes, 1) >= %L AND make_date(ano, mes, 1) <= %L
                        GROUP BY ano, mes
                    ) sub
                ), 0) as clientes
            FROM public.data_summary
            %s AND make_date(ano, mes, 1) >= %L AND make_date(ano, mes, 1) <= %L
        ),
        -- Products Table Using the NEW summary table
        prod_agg AS (
            SELECT
                sp.produto,
                dp.descricao,
                SUM(COALESCE(sp.caixas, 0)) as caixas,
                SUM(sp.vlvenda) as faturamento,
                SUM(sp.peso) as peso,
                COUNT(DISTINCT CASE WHEN tipovenda NOT IN (''5'', ''11'') AND sp.vlvenda >= 1 THEN sp.codcli END) as clientes,
                (SELECT MAX(dtped) FROM public.data_detailed WHERE produto = sp.produto LIMIT 1) as ultima_venda
            FROM public.data_summary_produtos sp
            LEFT JOIN public.dim_produtos dp ON sp.produto = dp.codigo
            %s AND sp.ano = %L %s
            GROUP BY 1, 2
            ORDER BY caixas DESC
        )
        SELECT
            (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas, ''clientes'', clientes)) FROM chart_agg),
            (SELECT row_to_json(c) FROM kpi_curr c),
            (SELECT row_to_json(p) FROM kpi_prev p),
            (SELECT row_to_json(t) FROM kpi_tri t),
            (SELECT json_agg(pa) FROM prod_agg pa)
    ',
    v_active_client_cond, v_where_summary, v_current_year, v_previous_year, -- Chart
    v_active_client_cond, v_where_summary, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Curr
    v_active_client_cond, v_where_summary, v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Prev
    v_active_client_cond, v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), -- KPI Tri
    v_where_produtos, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND sp.mes = %L ', v_target_month) ELSE '' END -- Prod Agg
    )
    INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;


    -- Enrich products_table with trend_estq
    IF v_products_table IS NOT NULL AND json_array_length(v_products_table) > 0 THEN
        WITH prod_keys AS (
            SELECT p->>'produto' as produto
            FROM json_array_elements(v_products_table) p
        ),
        prod_6m_agg AS (
            SELECT
                s.produto,
                SUM(COALESCE(s.caixas, 0)) as total_caixas_6m
            FROM public.data_summary_produtos s
            JOIN prod_keys pk ON pk.produto = s.produto
            JOIN dim_produtos dp ON dp.codigo = s.produto
            WHERE make_date(s.ano, s.mes, 1) >= date_trunc('month', GREATEST(dp.dt_cadastro, (v_max_sale_date - interval '6 months')::date))
            AND make_date(s.ano, s.mes, 1) <= date_trunc('month', v_max_sale_date)
            AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR s.filial = ANY(p_filial))
            AND s.tipovenda NOT IN ('5', '11')
            GROUP BY s.produto
        )
        SELECT json_agg(
            json_build_object(
                'produto', p->>'produto',
                'descricao', p->>'descricao',
                'caixas', (p->>'caixas')::numeric,
                'faturamento', (p->>'faturamento')::numeric,
                'peso', (p->>'peso')::numeric,
                'clientes', (p->>'clientes')::numeric,
                'ultima_venda', p->>'ultima_venda',
                'estoque', COALESCE(sub.estoque, 0),
                'tend_estq', CASE
                    WHEN COALESCE(sub.estoque, 0) = 0 THEN 0
                    WHEN COALESCE(sub.business_days, 0) = 0 THEN 0
                    WHEN COALESCE(agg.total_caixas_6m, 0) = 0 THEN 0
                    ELSE ROUND((COALESCE(sub.estoque, 0) / (agg.total_caixas_6m / sub.business_days))::numeric, 0)
                END
            )
        )
        INTO v_products_table
        FROM json_array_elements(v_products_table) p
        LEFT JOIN LATERAL (
            SELECT
                (
                    SELECT SUM(val::numeric)
                    FROM jsonb_each_text(dp.estoque_filial) AS f(key, val)
                    WHERE (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR key = ANY(p_filial))
                ) as estoque,
                public.calc_working_days(
                    GREATEST(dp.dt_cadastro, (v_max_sale_date - interval '6 months')::date),
                    v_max_sale_date
                ) as business_days
            FROM dim_produtos dp
            WHERE dp.codigo = p->>'produto'
        ) sub ON true
        LEFT JOIN prod_6m_agg agg ON agg.produto = p->>'produto';
    END IF;

    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0,"clientes":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json),
        'trend_info', json_build_object(
            'allowed', v_trend_allowed,
            'factor', v_trend_factor,
            'current_month_index', v_curr_month_idx
        )
    );
END;
$$;
