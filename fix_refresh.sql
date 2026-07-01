CREATE OR REPLACE FUNCTION refresh_summary_year(p_year int)
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
        ramo, caixas, categoria_produto, cnpj
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
            dp.categoria_produto -- Added
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
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
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        total_caixas,
        categoria_produto,
        NULL::text as cnpj
    FROM client_agg;


    -- Update data_summary_frequency for the year
    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo, cnpj
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
    raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto
        FROM public.data_detailed
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto
        FROM public.data_history
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
    ),
    order_prod_agg AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            s.filial,
            s.cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' THEN COALESCE(dp.codfor_enhanced, '1119_OUTROS')
                ELSE s.codfor
            END as codfor,
            s.codcli,
            s.tipovenda,
            s.pedido,
            s.produto,
            dp.categoria_produto,
            dp.mix_marca,
            SUM(s.vlvenda) as prod_vlvenda,
            SUM(s.totpesoliq) as prod_peso
        FROM raw_data s
        LEFT JOIN dim_prod_enhanced dp ON s.produto = dp.codigo
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    ),
    final_agg AS (
        SELECT
            op.ano,
            op.mes,
            op.filial,
            op.cidade,
            op.codsupervisor,
            op.codusur,
            op.codfor,
            op.codcli,
            op.tipovenda,
            op.pedido,
            SUM(op.prod_vlvenda) as vlvenda,
            SUM(op.prod_peso) as peso,
            jsonb_agg(op.produto) as produtos,
            jsonb_agg(op.categoria_produto) as categorias,
            c.ramo as rede,
            array_agg(op.produto) as produtos_arr,
            array_agg(op.categoria_produto) as categorias_arr,
            MAX(CASE WHEN op.mix_marca = 'CHEETOS' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_cheetos,
            MAX(CASE WHEN op.mix_marca = 'DORITOS' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_doritos,
            MAX(CASE WHEN op.mix_marca = 'FANDANGOS' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_fandangos,
            MAX(CASE WHEN op.mix_marca = 'RUFFLES' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_ruffles,
            MAX(CASE WHEN op.mix_marca = 'TORCIDA' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_torcida,
            MAX(CASE WHEN op.mix_marca = 'TODDYNHO' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_toddynho,
            MAX(CASE WHEN op.mix_marca = 'TODDY' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_toddy,
            MAX(CASE WHEN op.mix_marca = 'QUAKER' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_quaker,
            MAX(CASE WHEN op.mix_marca = 'KEROCOCO' AND op.prod_vlvenda >= 1 THEN 1 ELSE 0 END) as has_kerococo
        FROM order_prod_agg op
        LEFT JOIN public.data_clients c ON op.codcli = c.codigo_cliente
        GROUP BY
            op.ano,
            op.mes,
            op.filial,
            op.cidade,
            op.codsupervisor,
            op.codusur,
            op.codfor,
            op.codcli,
            op.tipovenda,
            op.pedido,
            c.ramo
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
        vlvenda,
        peso,
        produtos,
        categorias,
        rede,
        produtos_arr,
        categorias_arr,
        has_cheetos,
        has_doritos,
        has_fandangos,
        has_ruffles,
        has_torcida,
        has_toddynho,
        has_toddy,
        has_quaker,
        has_kerococo,
        NULL::text as cnpj
    FROM final_agg;
    -- ANALYZE public.data_summary;
END;
$$;