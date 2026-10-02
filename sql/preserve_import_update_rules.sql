-- Keeps every import/refresh path aligned with prior supervisor, seller and Foods fixes.
-- Apply after the older sql/fix_*.sql scripts; full_system_v1.sql is a baseline, not an upgrade.
CREATE OR REPLACE FUNCTION public.normalize_summary_vendor_assignments(p_year integer, p_month integer DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM private.evolution_assert_admin();
    UPDATE public.data_summary ds
       SET codusur = c.rca1
      FROM public.data_clients c
     WHERE ds.ano = p_year AND (p_month IS NULL OR ds.mes = p_month)
       AND ds.codcli = c.codigo_cliente AND ds.codusur LIKE 'INAT_%'
       AND c.rca1 IS NOT NULL AND c.rca1 <> ''
       AND EXISTS (SELECT 1 FROM public.dim_vendedores dv
                   WHERE dv.codigo = c.rca1
                     AND UPPER(COALESCE(dv.nome,'')) NOT LIKE 'INATIVOS%');

    UPDATE public.data_summary_frequency ds
       SET codusur = c.rca1
      FROM public.data_clients c
     WHERE ds.ano = p_year AND (p_month IS NULL OR ds.mes = p_month)
       AND ds.codcli = c.codigo_cliente AND ds.codusur LIKE 'INAT_%'
       AND c.rca1 IS NOT NULL AND c.rca1 <> ''
       AND EXISTS (SELECT 1 FROM public.dim_vendedores dv
                   WHERE dv.codigo = c.rca1
                     AND UPPER(COALESCE(dv.nome,'')) NOT LIKE 'INATIVOS%');
END;
$function$;
REVOKE ALL ON FUNCTION public.normalize_summary_vendor_assignments(integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.normalize_summary_vendor_assignments(integer,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.refresh_summary_chunk(p_start_date date, p_end_date date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_year int;
    v_month int;
BEGIN
    PERFORM private.evolution_assert_admin();
    SET LOCAL statement_timeout = '1800s'; -- Increased to 30 mins to avoid immediate API cutoff
    SET LOCAL work_mem = '128MB'; -- More memory for internal hashing during grouped inserts

    v_year := EXTRACT(YEAR FROM p_start_date);
    v_month := EXTRACT(MONTH FROM p_start_date);
    
    -- STEP B: Insert into data_summary using CTE
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao, 
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto
    )
    WITH tmp_raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_detailed
        WHERE dtped >= p_start_date AND dtped < p_end_date
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_history
        WHERE dtped >= p_start_date AND dtped < p_end_date
    ),
    dim_prod_enhanced AS (
        SELECT
            codigo,
            categoria_produto,
            qtde_embalagem_master,
            CASE
                WHEN '1119' = '1119' AND (descricao ILIKE '%TODDYNHO%' OR descricao ILIKE '%TODYNHO%') THEN '1119_TODDYNHO'
                WHEN '1119' = '1119' AND (descricao ILIKE '%TODDY %' OR UPPER(TRIM(descricao)) = 'TODDY') THEN '1119_TODDY'
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
        categoria_produto
    FROM client_agg;
    

    -- STEP C: Insert into data_summary_frequency using CTE
    INSERT INTO public.data_summary_frequency (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, peso, produtos, categorias, rede,
        produtos_arr, categorias_arr, has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo
    )
    WITH tmp_raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_detailed
        WHERE dtped >= p_start_date AND dtped < p_end_date
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda, pedido
        FROM public.data_history
        WHERE dtped >= p_start_date AND dtped < p_end_date
    ),
    dim_prod_enhanced AS (
        SELECT
            codigo,
            categoria_produto,
            mix_marca,
            CASE
                WHEN (descricao ILIKE '%TODDYNHO%' OR descricao ILIKE '%TODYNHO%') THEN '1119_TODDYNHO'
                WHEN (descricao ILIKE '%TODDY %' OR UPPER(TRIM(descricao)) = 'TODDY') THEN '1119_TODDY'
                WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                ELSE '1119_OUTROS'
            END as codfor_enhanced
        FROM public.dim_produtos
    ),
    order_prod_agg AS (
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
            t.produto,
            dp.categoria_produto,
            dp.mix_marca,
            SUM(t.vlvenda) as prod_vlvenda,
            SUM(t.totpesoliq) as prod_peso
        FROM tmp_raw_data t
        LEFT JOIN dim_prod_enhanced dp ON t.produto = dp.codigo
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
    ),
    freq_agg_base AS (
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
            jsonb_agg(DISTINCT op.produto) as produtos,
            jsonb_agg(DISTINCT op.categoria_produto) FILTER (WHERE op.categoria_produto IS NOT NULL) as categorias,
            array_agg(DISTINCT op.produto) as produtos_arr,
            array_agg(DISTINCT op.categoria_produto) FILTER (WHERE op.categoria_produto IS NOT NULL) as categorias_arr,
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
            op.pedido
    )
    SELECT
        f.ano,
        f.mes,
        f.filial,
        f.cidade,
        f.codsupervisor,
        f.codusur,
        f.codfor,
        f.codcli,
        f.tipovenda,
        f.pedido,
        f.vlvenda,
        f.peso,
        f.produtos,
        COALESCE(f.categorias, '[]'::jsonb) as categorias,
        c.ramo as rede,
        f.produtos_arr,
        f.categorias_arr,
        f.has_cheetos,
        f.has_doritos,
        f.has_fandangos,
        f.has_ruffles,
        f.has_torcida,
        f.has_toddynho,
        f.has_toddy,
        f.has_quaker,
        f.has_kerococo
    FROM freq_agg_base f
    LEFT JOIN public.data_clients c ON f.codcli = c.codigo_cliente;

    PERFORM public.normalize_summary_vendor_assignments(v_year, v_month);

    -- STEP D: Cleanup (No longer needed)
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_summary_month(p_year integer, p_month integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start date := make_date(p_year,p_month,1);
BEGIN
    PERFORM private.evolution_assert_admin();
    PERFORM public.clear_summary_month(p_year,p_month);
    -- Use the same maintained aggregation and seller normalization as UI imports.
    PERFORM public.refresh_summary_chunk(v_start,(v_start + interval '1 month')::date);
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_summary_year(p_year integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM private.evolution_assert_admin();
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
        -- ⚡ QueryTuner: Replacing EXTRACT(YEAR FROM dtped) = p_year with SARGable date ranges
        -- (dtped >= make_date(...) AND dtped <= make_date(...)) to enable Index Range Scans on dtped.
        -- EXPLAIN ANALYZE data_history: 2354ms (Parallel Seq Scan) -> 77ms (Index Scan/Append), 30x faster.
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda
        FROM public.data_detailed
        WHERE dtped >= make_date(p_year, 1, 1) AND dtped <= make_date(p_year, 12, 31)
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda
        FROM public.data_history
        WHERE dtped >= make_date(p_year, 1, 1) AND dtped <= make_date(p_year, 12, 31)
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
                WHEN s.codfor = '1119' AND (dp.descricao ILIKE '%TODDYNHO%' OR dp.descricao ILIKE '%TODYNHO%') THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND (dp.descricao ILIKE '%TODDY %' OR dp.descricao = 'TODDY') THEN '1119_TODDY'
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
        categoria_produto
    FROM client_agg;
    

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
                WHEN (descricao ILIKE '%TODDYNHO%' OR descricao ILIKE '%TODYNHO%') THEN '1119_TODDYNHO'
                WHEN (descricao ILIKE '%TODDY %' OR UPPER(TRIM(descricao)) = 'TODDY') THEN '1119_TODDY'
                WHEN descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                ELSE '1119_OUTROS'
            END as codfor_enhanced
        FROM public.dim_produtos
    ),
    raw_data AS (
        -- ⚡ QueryTuner: Replacing EXTRACT(YEAR FROM dtped) = p_year with SARGable date ranges
        -- (dtped >= make_date(...) AND dtped <= make_date(...)) to enable Index Range Scans on dtped.
        -- EXPLAIN ANALYZE data_history: 2354ms (Parallel Seq Scan) -> 77ms (Index Scan/Append), 30x faster.
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto 
        FROM public.data_detailed 
        WHERE dtped >= make_date(p_year, 1, 1) AND dtped <= make_date(p_year, 12, 31)
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, codcli, tipovenda, pedido, vlvenda, totpesoliq, produto 
        FROM public.data_history 
        WHERE dtped >= make_date(p_year, 1, 1) AND dtped <= make_date(p_year, 12, 31)
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
            jsonb_agg(DISTINCT op.produto) as produtos,
            jsonb_agg(DISTINCT op.categoria_produto) as categorias,
            c.ramo as rede,
            array_agg(DISTINCT op.produto) as produtos_arr,
            array_agg(DISTINCT op.categoria_produto) as categorias_arr,
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
        has_kerococo
    FROM final_agg;

    -- A carga de origem pode marcar vendedores ativos como INAT_*.
    -- Para os caches do dashboard, recuperamos o RCA atual do cliente quando
    -- houver um vendedor válido em dim_vendedores. Isso impede que todas as abas
    -- percam os filtros de vendedor após o refresh geral.
    PERFORM public.normalize_summary_vendor_assignments(p_year, NULL);

    -- ANALYZE public.data_summary;
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_cache_filters(p_ano integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    r RECORD;
BEGIN
    PERFORM private.evolution_assert_admin();
    SET LOCAL statement_timeout = '600s';
    
    IF p_ano IS NULL OR p_mes IS NULL THEN
        -- Instead of loop, use a single fast aggregated query for the full rebuild.
        TRUNCATE TABLE public.cache_filters;

        INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede, categoria_produto)
        WITH distinct_codes AS (
            SELECT
                filial,
                cidade,
                codsupervisor,
                codusur,
                codfor,
                tipovenda,
                ano,
                mes,
                ramo,
                categoria_produto
            FROM public.data_summary
            GROUP BY
                filial, cidade, codsupervisor, codusur, codfor, tipovenda, ano, mes, ramo, categoria_produto
        )
        SELECT
            dc.filial,
            dc.cidade,
            CASE
            WHEN dc.codsupervisor = '12' THEN 'TIAGO JOSÉ DE S'
            WHEN dc.codsupervisor IN ('18','21') THEN 'RÔMULO AMADO DA'
            WHEN dc.codsupervisor = 'SV_AMERICANAS' THEN 'SV AMERICANAS'
            WHEN dc.codsupervisor = '8' THEN 'BALCAO'
            ELSE ds.nome
        END as superv,
            dv.nome as nome,
            dc.codfor,
            CASE
                WHEN dc.codfor = '707' THEN 'EXTRUSADOS'
                WHEN dc.codfor = '708' THEN 'Ñ EXTRUSADOS'
                WHEN dc.codfor = '752' THEN 'TORCIDA'
                WHEN dc.codfor = '1119_TODDYNHO' THEN 'TODDYNHO'
                WHEN dc.codfor = '1119_TODDY' THEN 'TODDY'
                WHEN dc.codfor = '1119_QUAKER' THEN 'QUAKER'
                WHEN dc.codfor = '1119_KEROCOCO' THEN 'KEROCOCO'
                WHEN dc.codfor = '1119_OUTROS' THEN 'FOODS (Outros)'
                WHEN dc.codfor = '1119' THEN 'FOODS (Outros)'
                ELSE df.nome
            END as fornecedor,
            dc.tipovenda,
            dc.ano,
            dc.mes,
            dc.ramo as rede,
            dc.categoria_produto
        FROM distinct_codes dc
        LEFT JOIN public.dim_supervisores ds ON dc.codsupervisor = ds.codigo
        LEFT JOIN public.dim_vendedores dv ON dc.codusur = dv.codigo
        LEFT JOIN public.dim_fornecedores df ON dc.codfor = df.codigo;

        RETURN;
    END IF;

    -- Target specific month to keep transaction small
    DELETE FROM public.cache_filters WHERE ano = p_ano AND mes = p_mes;
    
    -- Optimize by getting distinct codes first, then joining dimensions
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede, categoria_produto)
    WITH distinct_codes AS (
        SELECT 
            filial, 
            cidade, 
            codsupervisor, 
            codusur, 
            codfor, 
            tipovenda, 
            ano, 
            mes, 
            ramo, 
            categoria_produto
        FROM public.data_summary
        WHERE ano = p_ano AND mes = p_mes
        GROUP BY 
            filial, cidade, codsupervisor, codusur, codfor, tipovenda, ano, mes, ramo, categoria_produto
    )
    SELECT 
        dc.filial, 
        dc.cidade, 
        CASE
            WHEN dc.codsupervisor = '12' THEN 'TIAGO JOSÉ DE S'
            WHEN dc.codsupervisor IN ('18','21') THEN 'RÔMULO AMADO DA'
            WHEN dc.codsupervisor = 'SV_AMERICANAS' THEN 'SV AMERICANAS'
            WHEN dc.codsupervisor = '8' THEN 'BALCAO'
            ELSE ds.nome
        END as superv, 
        dv.nome as nome, 
        dc.codfor,
        CASE 
            WHEN dc.codfor = '707' THEN 'EXTRUSADOS'
            WHEN dc.codfor = '708' THEN 'Ñ EXTRUSADOS'
            WHEN dc.codfor = '752' THEN 'TORCIDA'
            WHEN dc.codfor = '1119_TODDYNHO' THEN 'TODDYNHO'
            WHEN dc.codfor = '1119_TODDY' THEN 'TODDY'
            WHEN dc.codfor = '1119_QUAKER' THEN 'QUAKER'
            WHEN dc.codfor = '1119_KEROCOCO' THEN 'KEROCOCO'
            WHEN dc.codfor = '1119_OUTROS' THEN 'FOODS (Outros)'
            WHEN dc.codfor = '1119' THEN 'FOODS (Outros)'
            ELSE df.nome 
        END as fornecedor, 
        dc.tipovenda, 
        dc.ano, 
        dc.mes,
        dc.ramo as rede,
        dc.categoria_produto
    FROM distinct_codes dc
    LEFT JOIN public.dim_supervisores ds ON dc.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON dc.codusur = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON dc.codfor = df.codigo;
END;
$function$;

CREATE OR REPLACE FUNCTION public.classify_product_mix()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    -- 1. Legacy Mix Logic (Keep for backward compatibility)
    NEW.mix_marca := NULL;
    NEW.mix_categoria := NULL;

    IF NEW.descricao ILIKE '%CHEETOS%' THEN NEW.mix_marca := 'CHEETOS';
    ELSIF NEW.descricao ILIKE '%DORITOS%' THEN NEW.mix_marca := 'DORITOS';
    ELSIF NEW.descricao ILIKE '%FANDANGOS%' THEN NEW.mix_marca := 'FANDANGOS';
    ELSIF NEW.descricao ILIKE '%RUFFLES%' THEN NEW.mix_marca := 'RUFFLES';
    ELSIF NEW.descricao ILIKE '%TORCIDA%' THEN NEW.mix_marca := 'TORCIDA';
    ELSIF (NEW.descricao ILIKE '%TODDYNHO%' OR NEW.descricao ILIKE '%TODYNHO%') THEN NEW.mix_marca := 'TODDYNHO';
    ELSIF (NEW.descricao ILIKE '%TODDY %' OR UPPER(TRIM(NEW.descricao)) = 'TODDY') THEN NEW.mix_marca := 'TODDY';
    ELSIF NEW.descricao ILIKE '%QUAKER%' THEN NEW.mix_marca := 'QUAKER';
    ELSIF NEW.descricao ILIKE '%KEROCOCO%' THEN NEW.mix_marca := 'KEROCOCO';
    END IF;

    IF NEW.mix_marca IN ('CHEETOS', 'DORITOS', 'FANDANGOS', 'RUFFLES', 'TORCIDA') THEN
        NEW.mix_categoria := 'SALTY';
    ELSIF NEW.mix_marca IN ('TODDYNHO', 'TODDY', 'QUAKER', 'KEROCOCO') THEN
        NEW.mix_categoria := 'FOODS';
    END IF;

    -- 2. New Robust Category Logic (categoria_produto)
    NEW.categoria_produto := 'OUTROS'; -- Default

    -- Priority Matches (Specific Variations & Sub-brands)
    IF NEW.descricao ILIKE '%CHEETOS CRUNCHY%' THEN NEW.categoria_produto := 'CHEETOS CRUNCHY';
    ELSIF NEW.descricao ILIKE '%DORITOS DIN%' THEN NEW.categoria_produto := 'DORITOS DINAMITA';
    ELSIF NEW.descricao ILIKE '%LAYS RUSTICAS%' THEN NEW.categoria_produto := 'LAYS RUSTICA';
    ELSIF NEW.descricao ILIKE '%STAX%' THEN NEW.categoria_produto := 'STAX'; -- Check before LAYS
    ELSIF NEW.descricao ILIKE '%SENSACOES%' THEN NEW.categoria_produto := 'SENSACOES'; -- Check before LAYS
    
    -- General Matches
    ELSIF NEW.descricao ILIKE '%BACONZITOS%' THEN NEW.categoria_produto := 'BACONZITOS';
    ELSIF NEW.descricao ILIKE '%CEBOLITOS%' THEN NEW.categoria_produto := 'CEBOLITOS';
    ELSIF NEW.descricao ILIKE '%SKINY%' THEN NEW.categoria_produto := 'SKINY';
    ELSIF NEW.descricao ILIKE '%CHEETOS%' THEN NEW.categoria_produto := 'CHEETOS';
    ELSIF NEW.descricao ILIKE '%DORITOS%' THEN NEW.categoria_produto := 'DORITOS';
    ELSIF NEW.descricao ILIKE '%AMENDOIM%' THEN NEW.categoria_produto := 'ELMA-CHIPS AMENDOIM';
    ELSIF NEW.descricao ILIKE '%PALHA%' THEN NEW.categoria_produto := 'ELMA-CHIPS PALHA';
    ELSIF NEW.descricao ILIKE '%FANDANGOS%' THEN NEW.categoria_produto := 'FANDANGOS';
    ELSIF NEW.descricao ILIKE '%LANCHINHO%' THEN NEW.categoria_produto := 'LANCHINHO';
    ELSIF NEW.descricao ILIKE '%LAYS%' THEN NEW.categoria_produto := 'LAYS';
    ELSIF NEW.descricao ILIKE '%PINGO DOURO%' THEN NEW.categoria_produto := 'PINGO DOURO';
    ELSIF NEW.descricao ILIKE '%POPCORNERS%' THEN NEW.categoria_produto := 'POPCORNERS';
    ELSIF NEW.descricao ILIKE '%RUFFLES%' THEN NEW.categoria_produto := 'RUFFLES';
    -- SENSACOES moved up
    -- STAX moved up
    ELSIF NEW.descricao ILIKE '%STIKSY%' THEN NEW.categoria_produto := 'STIKSY';
    ELSIF NEW.descricao ILIKE '%TOSTITOS%' THEN NEW.categoria_produto := 'TOSTITOS';
    ELSIF NEW.descricao ILIKE '%EQLIBRI%' THEN NEW.categoria_produto := 'EQLIBRI';
    ELSIF NEW.descricao ILIKE '%FOFURA%' THEN NEW.categoria_produto := 'FOFURA';
    ELSIF NEW.descricao ILIKE '%TORCIDA%' THEN NEW.categoria_produto := 'TORCIDA';
    
    -- Foods / Others (Mapped to same names as legacy mix but in new column)
    ELSIF (NEW.descricao ILIKE '%TODDYNHO%' OR NEW.descricao ILIKE '%TODYNHO%') THEN NEW.categoria_produto := 'TODDYNHO';
    ELSIF (NEW.descricao ILIKE '%TODDY %' OR UPPER(TRIM(NEW.descricao)) = 'TODDY') THEN NEW.categoria_produto := 'TODDY';
    ELSIF NEW.descricao ILIKE '%QUAKER%' THEN NEW.categoria_produto := 'QUAKER';
    ELSIF NEW.descricao ILIKE '%KEROCOCO%' THEN NEW.categoria_produto := 'KEROCOCO';
    END IF;

    RETURN NEW;
END;
$function$;

-- Normalize the existing dimension too; future imports enforce the same names.
UPDATE public.dim_supervisores SET nome = CASE WHEN codigo = '12' THEN 'TIAGO JOSÉ DE S' ELSE 'RÔMULO AMADO DA' END WHERE codigo IN ('12','18','21');
