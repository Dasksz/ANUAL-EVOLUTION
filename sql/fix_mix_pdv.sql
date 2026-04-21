-- Deploy the updated refresh_summary_year and refresh_summary_chunk functions
-- that compute `pre_mix_count` accurately without double counting per tipovenda.

-- 1. Redefine refresh_summary_year
CREATE OR REPLACE FUNCTION public.refresh_summary_year(p_year int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Clear data for this year first (avoid duplicates)
    DELETE FROM public.data_summary WHERE ano = p_year;
    DELETE FROM public.data_summary_frequency WHERE ano = p_year;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda
        FROM public.data_detailed
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda
        FROM public.data_history
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda, dp.qtde_embalagem_master,
            c.ramo,
            dp.categoria_produto
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    ),
    product_agg_all AS (
        SELECT
            ano, mes, codcli, codfor, produto,
            SUM(vlvenda) as total_prod_val
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5
    ),
    client_true_mix AS (
        SELECT
            ano, mes, codcli, codfor,
            COUNT(CASE WHEN total_prod_val >= 1 THEN 1 END) as true_mix_calc
        FROM product_agg_all
        GROUP BY 1, 2, 3, 4
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    ),
    client_agg_base AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            ROW_NUMBER() OVER (PARTITION BY pa.ano, pa.mes, pa.codcli, pa.codfor ORDER BY SUM(pa.prod_val) DESC, pa.tipovenda ASC) as rn
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    )
    SELECT
        b.ano, b.mes, b.filial, b.cidade, b.codsupervisor, b.codusur, b.codfor, b.tipovenda, b.codcli,
        b.total_val, b.total_peso, b.total_bonific, b.total_devol,
        CASE WHEN b.rn = 1 THEN COALESCE(tm.true_mix_calc, 0) ELSE 0 END as mix_calc,
        CASE WHEN b.total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        b.ramo,
        b.total_caixas,
        b.categoria_produto
    FROM client_agg_base b
    LEFT JOIN client_true_mix tm ON b.ano = tm.ano AND b.mes = tm.mes AND b.codcli = tm.codcli AND b.codfor = tm.codfor;


    -- Update data_summary_frequency for the year
    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo
    )
    WITH dim_prod_enhanced AS (
        SELECT
            codigo,
            categoria_produto,
            mix_marca,
            CASE
                WHEN descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                ELSE '1119_OUTROS'
            END as codfor_enhanced
        FROM public.dim_produtos
    )
    SELECT
        EXTRACT(YEAR FROM s.dtped)::int as ano,
        EXTRACT(MONTH FROM s.dtped)::int as mes,
        CASE
            WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
            ELSE s.filial
        END as filial,
        COALESCE(s.cidade, c.cidade) as cidade,
        s.codsupervisor,
        s.codusur,
        CASE
            WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
            ELSE s.codfor
        END as codfor,
        s.codcli,
        s.tipovenda,
        s.pedido,
        SUM(s.vlvenda) as vlvenda,
        SUM(s.totpesoliq) as peso,
        jsonb_agg(DISTINCT s.produto) as produtos,
        jsonb_agg(DISTINCT dp.categoria_produto) FILTER (WHERE dp.categoria_produto IS NOT NULL) as categorias,
        c.ramo as rede,
        array_agg(DISTINCT s.produto) as produtos_arr,
        array_agg(DISTINCT dp.categoria_produto) FILTER (WHERE dp.categoria_produto IS NOT NULL) as categorias_arr,
        MAX(CASE WHEN dp.mix_marca = 'CHEETOS' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_cheetos,
        MAX(CASE WHEN dp.mix_marca = 'DORITOS' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_doritos,
        MAX(CASE WHEN dp.mix_marca = 'FANDANGOS' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_fandangos,
        MAX(CASE WHEN dp.mix_marca = 'RUFFLES' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_ruffles,
        MAX(CASE WHEN dp.mix_marca = 'TORCIDA' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_torcida,
        MAX(CASE WHEN dp.mix_marca = 'TODDYNHO' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_toddynho,
        MAX(CASE WHEN dp.mix_marca = 'TODDY' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_toddy,
        MAX(CASE WHEN dp.mix_marca = 'QUAKER' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_quaker,
        MAX(CASE WHEN dp.mix_marca = 'KEROCOCO' AND s.vlvenda >= 1 THEN 1 ELSE NULL END) as has_kerococo
    FROM (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto FROM public.data_detailed WHERE EXTRACT(YEAR FROM dtped)::int = p_year
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto FROM public.data_history WHERE EXTRACT(YEAR FROM dtped)::int = p_year
    ) s
    LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
    LEFT JOIN dim_prod_enhanced dp ON s.produto = dp.codigo
    GROUP BY
        EXTRACT(YEAR FROM s.dtped)::int,
        EXTRACT(MONTH FROM s.dtped)::int,
        CASE
            WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
            ELSE s.filial
        END,
        COALESCE(s.cidade, c.cidade),
        s.codsupervisor,
        s.codusur,
        CASE
            WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
            ELSE s.codfor
        END,
        s.codcli,
        s.tipovenda,
        s.pedido,
        c.ramo;
END;
$$;


-- 2. Redefine refresh_summary_chunk
CREATE OR REPLACE FUNCTION public.refresh_summary_chunk(p_start_date date, p_end_date date)
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
    SET LOCAL work_mem = '128MB'; -- More memory for internal hashing during grouped inserts

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

    -- STEP B: Insert into data_summary using the temporary table
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto
    )
    WITH dim_prod_enhanced AS (
        SELECT
            codigo,
            categoria_produto,
            qtde_embalagem_master,
            CASE
                WHEN '1119' = '1119' AND descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN '1119' = '1119' AND descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN '1119' = '1119' AND descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN '1119' = '1119' AND descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                ELSE '1119_OUTROS'
            END as codfor_enhanced
        FROM public.dim_produtos
    ),
    augmented_data AS (
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
            dp.categoria_produto
        FROM tmp_raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN dim_prod_enhanced dp ON s.produto = dp.codigo
    ),
    product_agg_all AS (
        SELECT
            ano, mes, codcli, codfor, produto,
            SUM(vlvenda) as total_prod_val
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5
    ),
    client_true_mix AS (
        SELECT
            ano, mes, codcli, codfor,
            COUNT(CASE WHEN total_prod_val >= 1 THEN 1 END) as true_mix_calc
        FROM product_agg_all
        GROUP BY 1, 2, 3, 4
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    ),
    client_agg_base AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            ROW_NUMBER() OVER (PARTITION BY pa.ano, pa.mes, pa.codcli, pa.codfor ORDER BY SUM(pa.prod_val) DESC, pa.tipovenda ASC) as rn
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    )
    SELECT
        b.ano, b.mes, b.filial, b.cidade, b.codsupervisor, b.codusur, b.codfor, b.tipovenda, b.codcli,
        b.total_val, b.total_peso, b.total_bonific, b.total_devol,
        CASE WHEN b.rn = 1 THEN COALESCE(tm.true_mix_calc, 0) ELSE 0 END as mix_calc,
        CASE WHEN b.total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        b.ramo,
        b.total_caixas,
        b.categoria_produto
    FROM client_agg_base b
    LEFT JOIN client_true_mix tm ON b.ano = tm.ano AND b.mes = tm.mes AND b.codcli = tm.codcli AND b.codfor = tm.codfor;


    -- STEP C: Insert into data_summary_frequency using the temporary table
    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo
    )
    WITH dim_prod_enhanced AS (
        SELECT
            codigo,
            categoria_produto,
            mix_marca,
            CASE
                WHEN descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                ELSE '1119_OUTROS'
            END as codfor_enhanced
        FROM public.dim_produtos
    ),
    freq_agg_base AS (
        SELECT
            v_year as ano,
            v_month as mes,
            t.filial,
            t.cidade,
            t.codsupervisor,
            t.codusur,
            CASE
                WHEN t.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
                ELSE t.codfor
            END as codfor,
            t.codcli,
            t.tipovenda,
            t.pedido,
            SUM(t.vlvenda) as vlvenda,
            SUM(t.totpesoliq) as peso,
            jsonb_agg(DISTINCT t.produto) as produtos,
            jsonb_agg(DISTINCT dp.categoria_produto) FILTER (WHERE dp.categoria_produto IS NOT NULL) as categorias,
            array_agg(DISTINCT t.produto) as produtos_arr,
            array_agg(DISTINCT dp.categoria_produto) FILTER (WHERE dp.categoria_produto IS NOT NULL) as categorias_arr,
            MAX(CASE WHEN dp.mix_marca = 'CHEETOS' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_cheetos,
            MAX(CASE WHEN dp.mix_marca = 'DORITOS' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_doritos,
            MAX(CASE WHEN dp.mix_marca = 'FANDANGOS' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_fandangos,
            MAX(CASE WHEN dp.mix_marca = 'RUFFLES' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_ruffles,
            MAX(CASE WHEN dp.mix_marca = 'TORCIDA' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_torcida,
            MAX(CASE WHEN dp.mix_marca = 'TODDYNHO' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_toddynho,
            MAX(CASE WHEN dp.mix_marca = 'TODDY' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_toddy,
            MAX(CASE WHEN dp.mix_marca = 'QUAKER' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_quaker,
            MAX(CASE WHEN dp.mix_marca = 'KEROCOCO' AND t.vlvenda >= 1 THEN 1 ELSE NULL END) as has_kerococo
        FROM tmp_raw_data t
        LEFT JOIN dim_prod_enhanced dp ON t.produto = dp.codigo
        GROUP BY
            v_year, v_month, t.filial, t.cidade, t.codsupervisor, t.codusur,
            CASE WHEN t.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS') ELSE t.codfor END,
            t.codcli, t.tipovenda, t.pedido
    )
    SELECT
        f.ano, f.mes,
        CASE WHEN f.codcli = '11625' AND f.ano = 2025 AND f.mes = 12 THEN '05' ELSE f.filial END,
        COALESCE(f.cidade, c.cidade), f.codsupervisor, f.codusur, f.codfor, f.codcli, f.tipovenda, f.pedido,
        f.vlvenda, f.peso, f.produtos, f.categorias, c.ramo,
        f.produtos_arr, f.categorias_arr, f.has_cheetos, f.has_doritos, f.has_fandangos, f.has_ruffles, f.has_torcida, f.has_toddynho, f.has_toddy, f.has_quaker, f.has_kerococo
    FROM freq_agg_base f
    LEFT JOIN public.data_clients c ON f.codcli = c.codigo_cliente;

    -- STEP D: Cleanup
    DROP TABLE IF EXISTS tmp_raw_data;
END;
$$;
