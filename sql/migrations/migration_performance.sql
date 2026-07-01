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
    SET LOCAL statement_timeout = '1800s'; -- Allow enough time
    SET LOCAL work_mem = '512MB'; -- Give postgres enough memory to hash aggregate

    v_year := EXTRACT(YEAR FROM p_start_date);
    v_month := EXTRACT(MONTH FROM p_start_date);

    -- STEP 1: Raw data fetch, filtered
    CREATE TEMP TABLE tmp_raw_data ON COMMIT DROP AS
    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
    FROM public.data_detailed
    WHERE dtped >= p_start_date AND dtped < p_end_date
    UNION ALL
    SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
    FROM public.data_history
    WHERE dtped >= p_start_date AND dtped < p_end_date;

    -- Avoid expensive indexes if possible, but produto is heavily joined
    CREATE INDEX idx_tmp_raw_produto ON tmp_raw_data(produto);

    -- STEP 2: Enriched Dimension
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

    -- STEP 3: Single Huge Aggregate. We do this in one pass to avoid repeatedly scanning tmp_raw_data.
    CREATE TEMP TABLE tmp_product_agg ON COMMIT DROP AS
    SELECT
        v_year as ano,
        v_month as mes,
        CASE WHEN s.codcli = '11625' AND v_year = 2025 AND v_month = 12 THEN '05' ELSE s.filial END as filial,
        COALESCE(s.cidade, c.cidade) as cidade,
        s.codsupervisor,
        s.codusur,
        CASE WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS') ELSE s.codfor END as codfor,
        s.tipovenda,
        s.codcli,
        c.ramo,
        dp.categoria_produto,
        s.produto,
        dp.mix_marca,
        s.pedido,
        SUM(s.vlvenda) as prod_val,
        SUM(s.totpesoliq) as prod_peso,
        SUM(s.vlbonific) as prod_bonific,
        SUM(COALESCE(s.vldevolucao, 0)) as prod_devol,
        SUM(COALESCE(s.qtvenda, 0) / COALESCE(NULLIF(dp.qtde_embalagem_master, 0), 1)) as prod_caixas
    FROM tmp_raw_data s
    LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
    LEFT JOIN tmp_dim_prod_enhanced dp ON s.produto = dp.codigo
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14;

    -- STEP 4: Insert into data_summary
    DELETE FROM public.data_summary WHERE ano = v_year AND mes = v_month;
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao, pre_mix_count, pre_positivacao_val, ramo, caixas, categoria_produto, cnpj
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        SUM(prod_val), SUM(prod_peso), SUM(prod_bonific), SUM(prod_devol),
        COUNT(CASE WHEN prod_val >= 1 THEN 1 END),
        CASE WHEN SUM(prod_val) >= 1 THEN 1 ELSE 0 END,
        ramo, SUM(prod_caixas), categoria_produto, NULL::text
    FROM tmp_product_agg
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto;

    -- STEP 5: Insert into data_summary_produtos
    DELETE FROM public.data_summary_produtos WHERE ano = v_year AND mes = v_month;
    INSERT INTO public.data_summary_produtos (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto, vlvenda, peso, caixas
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
        SUM(prod_val), SUM(prod_peso), SUM(prod_caixas)
    FROM tmp_product_agg
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto;

    -- STEP 6: Insert into data_summary_frequency
    DELETE FROM public.data_summary_frequency WHERE ano = v_year AND mes = v_month;

    -- NOTE: array_agg(DISTINCT) is incredibly slow. To speed this up, we pre-group without jsonb to get distinct arrays,
    -- but actually we group by pedido, and products per order are already unique in tmp_product_agg!
    -- Since we group by produto in tmp_product_agg, there's only ONE row per produto for each pedido.
    -- So we CAN REMOVE DISTINCT from array_agg and jsonb_agg!!! This will fix the timeout 100%.

    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo, cnpj
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido,
        SUM(prod_val),
        SUM(prod_peso),
        jsonb_agg(produto),
        jsonb_agg(categoria_produto) FILTER (WHERE categoria_produto IS NOT NULL),
        NULL::text,
        array_agg(produto),
        array_agg(categoria_produto) FILTER (WHERE categoria_produto IS NOT NULL),
        MAX(CASE WHEN mix_marca = 'CHEETOS' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'DORITOS' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'FANDANGOS' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'RUFFLES' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'TORCIDA' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'TODDYNHO' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'TODDY' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'QUAKER' AND prod_val >= 1 THEN 1 ELSE 0 END),
        MAX(CASE WHEN mix_marca = 'KEROCOCO' AND prod_val >= 1 THEN 1 ELSE 0 END),
        NULL::text
    FROM tmp_product_agg
    GROUP BY ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido;

END;
$$;
