CREATE OR REPLACE FUNCTION public.get_metas_base_comparativo_filtered(p_ano integer, p_mes integer, p_filial text DEFAULT 'Todas'::text, p_fornecedor text DEFAULT 'Todos'::text, p_codsupervisor text DEFAULT NULL::text, p_codusur text DEFAULT NULL::text, p_categoria text DEFAULT 'Todos'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_date DATE := make_date(p_ano, p_mes, 1);
    v_start_date DATE := v_date - INTERVAL '3 months';
    v_m1 DATE := v_start_date;
    v_m2 DATE := v_start_date + INTERVAL '1 month';
    v_m3 DATE := v_start_date + INTERVAL '2 months';
    
    v_m1_key TEXT := to_char(v_m1, 'YYYY-MM');
    v_m2_key TEXT := to_char(v_m2, 'YYYY-MM');
    v_m3_key TEXT := to_char(v_m3, 'YYYY-MM');
    
    v_m1_label TEXT := upper(to_char(v_m1, 'TMMon YY'));
    v_m2_label TEXT := upper(to_char(v_m2, 'TMMon YY'));
    v_m3_label TEXT := upper(to_char(v_m3, 'TMMon YY'));

    v_result JSONB;
BEGIN
    PERFORM private.evolution_assert_approved();
    WITH raw_sales_all AS (
        SELECT 
            d.codusur,
            to_char(d.dtped, 'YYYY-MM') AS month_key,
            d.codfor,
            dp.categoria_produto,
            dp.mix_marca,
            d.vlvenda,
            d.totpesoliq,
            d.codcli,
            d.tipovenda
        FROM public.data_detailed d
        LEFT JOIN public.dim_produtos dp ON d.produto = dp.codigo
        WHERE d.dtped >= v_start_date AND d.dtped < v_date
          AND d.tipovenda IN ('1', '9')
          AND (p_filial IS NULL OR p_filial = '' OR p_filial = 'Todas' OR d.filial::text = p_filial)
          AND (
              p_codsupervisor IS NULL OR p_codsupervisor = ''
              OR d.codsupervisor::text = p_codsupervisor
              OR d.codsupervisor::text IN (
                  SELECT codigo::text FROM public.dim_supervisores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codsupervisor))
              )
          )
          AND (
              p_codusur IS NULL OR p_codusur = ''
              OR d.codusur::text = p_codusur
              OR d.codusur::text IN (
                  SELECT codigo::text FROM public.dim_vendedores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codusur))
              )
          )
          AND (
              p_fornecedor IS NULL OR p_fornecedor = '' OR p_fornecedor = 'Todos'
              OR (p_fornecedor IN ('707','708','752') AND LTRIM(d.codfor::text,'0') = p_fornecedor)
              OR (p_fornecedor = '1119_TODDYNHO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'TODDYNHO' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODDYNHO%' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODYNHO%'))
              OR (p_fornecedor = '1119_TODDY' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'TODDY' OR UPPER(COALESCE(dp.categoria_produto,'')) = 'TODDY' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODDY %'))
              OR (p_fornecedor = '1119_QUAKER_KEROCOCO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) IN ('QUAKER','KEROCOCO')
                       OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%QUAKER%'
                       OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%KEROCOCO%'))
              OR (p_fornecedor = '1119_QUAKER' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'QUAKER' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%QUAKER%'))
              OR (p_fornecedor = '1119_KEROCOCO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'KEROCOCO' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%KEROCOCO%'))
              OR (p_fornecedor = '1119' AND LTRIM(d.codfor::text,'0') = '1119')
          )
          AND (
              p_categoria IS NULL OR p_categoria = '' OR p_categoria = 'Todos'
              OR UPPER(COALESCE(dp.categoria_produto,'')) = UPPER(p_categoria)
              OR UPPER(COALESCE(dp.mix_marca,'')) = UPPER(p_categoria)
          )
        UNION ALL
        SELECT 
            d.codusur,
            to_char(d.dtped, 'YYYY-MM') AS month_key,
            d.codfor,
            dp.categoria_produto,
            dp.mix_marca,
            d.vlvenda,
            d.totpesoliq,
            d.codcli,
            d.tipovenda
        FROM public.data_history d
        LEFT JOIN public.dim_produtos dp ON d.produto = dp.codigo
        WHERE d.dtped >= v_start_date AND d.dtped < v_date
          AND d.tipovenda IN ('1', '9')
          AND (p_filial IS NULL OR p_filial = '' OR p_filial = 'Todas' OR d.filial::text = p_filial)
          AND (
              p_codsupervisor IS NULL OR p_codsupervisor = ''
              OR d.codsupervisor::text = p_codsupervisor
              OR d.codsupervisor::text IN (
                  SELECT codigo::text FROM public.dim_supervisores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codsupervisor))
              )
          )
          AND (
              p_codusur IS NULL OR p_codusur = ''
              OR d.codusur::text = p_codusur
              OR d.codusur::text IN (
                  SELECT codigo::text FROM public.dim_vendedores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codusur))
              )
          )
          AND (
              p_fornecedor IS NULL OR p_fornecedor = '' OR p_fornecedor = 'Todos'
              OR (p_fornecedor IN ('707','708','752') AND LTRIM(d.codfor::text,'0') = p_fornecedor)
              OR (p_fornecedor = '1119_TODDYNHO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'TODDYNHO' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODDYNHO%' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODYNHO%'))
              OR (p_fornecedor = '1119_TODDY' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'TODDY' OR UPPER(COALESCE(dp.categoria_produto,'')) = 'TODDY' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%TODDY %'))
              OR (p_fornecedor = '1119_QUAKER_KEROCOCO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) IN ('QUAKER','KEROCOCO')
                       OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%QUAKER%'
                       OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%KEROCOCO%'))
              OR (p_fornecedor = '1119_QUAKER' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'QUAKER' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%QUAKER%'))
              OR (p_fornecedor = '1119_KEROCOCO' AND LTRIM(d.codfor::text,'0') = '1119'
                  AND (UPPER(COALESCE(dp.mix_marca,'')) = 'KEROCOCO' OR UPPER(COALESCE(dp.categoria_produto,'')) LIKE '%KEROCOCO%'))
              OR (p_fornecedor = '1119' AND LTRIM(d.codfor::text,'0') = '1119')
          )
          AND (
              p_categoria IS NULL OR p_categoria = '' OR p_categoria = 'Todos'
              OR UPPER(COALESCE(dp.categoria_produto,'')) = UPPER(p_categoria)
              OR UPPER(COALESCE(dp.mix_marca,'')) = UPPER(p_categoria)
          )
    ),
    raw_sales AS (
        SELECT * FROM raw_sales_all
    ),
    client_month_mix AS (
        SELECT 
            codusur,
            month_key,
            codcli,
            MAX(CASE WHEN mix_marca = 'CHEETOS' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_cheetos,
            MAX(CASE WHEN mix_marca = 'DORITOS' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_doritos,
            MAX(CASE WHEN mix_marca = 'FANDANGOS' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_fandangos,
            MAX(CASE WHEN mix_marca = 'RUFFLES' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_ruffles,
            MAX(CASE WHEN mix_marca = 'TORCIDA' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_torcida,
            
            MAX(CASE WHEN mix_marca = 'TODDYNHO' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_toddynho,
            MAX(CASE WHEN mix_marca = 'TODDY' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_toddy,
            MAX(CASE WHEN mix_marca = 'QUAKER' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_quaker,
            MAX(CASE WHEN mix_marca = 'KEROCOCO' AND vlvenda > 0 THEN 1 ELSE 0 END) AS has_kerococo
        FROM raw_sales
        GROUP BY codusur, month_key, codcli
    ),
    seller_month_mix_agg AS (
        SELECT
            codusur,
            month_key,
            COUNT(CASE WHEN has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1 THEN 1 END) AS mix_salty,
            COUNT(CASE WHEN has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1 THEN 1 END) AS mix_foods
        FROM client_month_mix
        GROUP BY codusur, month_key
    ),
    seller_month_agg AS (
        SELECT 
            codusur,
            month_key,
            
            -- GERAL
            SUM(vlvenda) AS fat_geral,
            SUM(totpesoliq) AS vol_geral,
            COUNT(DISTINCT codcli) AS pos_geral,
            
            -- TOTAL ELMA
            SUM(CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN vlvenda ELSE 0 END) AS fat_elma,
            SUM(CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN totpesoliq ELSE 0 END) AS vol_elma,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') AND vlvenda > 0 THEN codcli END) AS pos_elma,
            
            -- 707
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '707' THEN vlvenda ELSE 0 END) AS fat_707,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '707' AND vlvenda > 0 THEN codcli END) AS pos_707,
            
            -- 708
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '708' THEN vlvenda ELSE 0 END) AS fat_708,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '708' AND vlvenda > 0 THEN codcli END) AS pos_708,
            
            -- 752
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '752' THEN vlvenda ELSE 0 END) AS fat_752,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '752' AND vlvenda > 0 THEN codcli END) AS pos_752,
            
            -- TOTAL FOODS
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN vlvenda ELSE 0 END) AS fat_foods,
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN totpesoliq ELSE 0 END) AS vol_foods,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND vlvenda > 0 THEN codcli END) AS pos_foods,
            
            -- TODDYNHO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%') THEN vlvenda ELSE 0 END) AS fat_toddynho,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%') AND vlvenda > 0 THEN codcli END) AS pos_toddynho,
            
            -- TODDY
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY') THEN vlvenda ELSE 0 END) AS fat_toddy,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY') AND vlvenda > 0 THEN codcli END) AS pos_toddy,
            
            -- QUAKER KEROCOCO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%') THEN vlvenda ELSE 0 END) AS fat_quaker_kerococo,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%') AND vlvenda > 0 THEN codcli END) AS pos_quaker_kerococo

        FROM raw_sales
        GROUP BY codusur, month_key
    ),
    seller_totals AS (
        SELECT 
            sma.codusur,
            dv.nome AS vendedor_nome,
            ds.nome AS supervisor_nome,
            ds.codigo AS supervisor_codigo,
            
            -- GERAL
            COALESCE(SUM(fat_geral), 0) AS total_fat_geral,
            COALESCE(SUM(vol_geral), 0) AS total_vol_geral,
            COALESCE(SUM(pos_geral), 0) AS sum_pos_geral,
            
            -- ELMA
            COALESCE(SUM(fat_elma), 0) AS total_fat_elma,
            COALESCE(SUM(vol_elma), 0) AS total_vol_elma,
            COALESCE(SUM(pos_elma), 0) AS sum_pos_elma,
            jsonb_object_agg(sma.month_key, COALESCE(fat_elma, 0)) AS history_fat_elma,
            
            -- 707
            COALESCE(SUM(fat_707), 0) AS total_fat_707,
            COALESCE(SUM(pos_707), 0) AS sum_pos_707,
            jsonb_object_agg(sma.month_key, COALESCE(fat_707, 0)) AS history_fat_707,
            
            -- 708
            COALESCE(SUM(fat_708), 0) AS total_fat_708,
            COALESCE(SUM(pos_708), 0) AS sum_pos_708,
            jsonb_object_agg(sma.month_key, COALESCE(fat_708, 0)) AS history_fat_708,
            
            -- 752
            COALESCE(SUM(fat_752), 0) AS total_fat_752,
            COALESCE(SUM(pos_752), 0) AS sum_pos_752,
            jsonb_object_agg(sma.month_key, COALESCE(fat_752, 0)) AS history_fat_752,
            
            -- FOODS
            COALESCE(SUM(fat_foods), 0) AS total_fat_foods,
            COALESCE(SUM(vol_foods), 0) AS total_vol_foods,
            COALESCE(SUM(pos_foods), 0) AS sum_pos_foods,
            jsonb_object_agg(sma.month_key, COALESCE(fat_foods, 0)) AS history_fat_foods,
            
            -- TODDYNHO
            COALESCE(SUM(fat_toddynho), 0) AS total_fat_toddynho,
            COALESCE(SUM(pos_toddynho), 0) AS sum_pos_toddynho,
            jsonb_object_agg(sma.month_key, COALESCE(fat_toddynho, 0)) AS history_fat_toddynho,
            
            -- TODDY
            COALESCE(SUM(fat_toddy), 0) AS total_fat_toddy,
            COALESCE(SUM(pos_toddy), 0) AS sum_pos_toddy,
            jsonb_object_agg(sma.month_key, COALESCE(fat_toddy, 0)) AS history_fat_toddy,
            
            -- QUAKER KEROCOCO
            COALESCE(SUM(fat_quaker_kerococo), 0) AS total_fat_quaker_kerococo,
            COALESCE(SUM(pos_quaker_kerococo), 0) AS sum_pos_quaker_kerococo,
            jsonb_object_agg(sma.month_key, COALESCE(fat_quaker_kerococo, 0)) AS history_fat_quaker_kerococo,
            
            -- MIX
            COALESCE(SUM(smma.mix_salty), 0) AS sum_mix_salty,
            COALESCE(SUM(smma.mix_foods), 0) AS sum_mix_foods

        FROM seller_month_agg sma
        LEFT JOIN seller_month_mix_agg smma ON sma.codusur = smma.codusur AND sma.month_key = smma.month_key
        LEFT JOIN public.dim_vendedores dv ON sma.codusur = dv.codigo
        -- Assuming dim_vendedores doesn't have supervisor directly, we can get it from data_clients by finding the most common supervisor for this seller
        LEFT JOIN LATERAL (
            SELECT codsupervisor 
            FROM public.data_summary ds_lat 
            WHERE ds_lat.codusur = sma.codusur 
            GROUP BY codsupervisor 
            ORDER BY COUNT(*) DESC 
            LIMIT 1
        ) as sup ON true
        LEFT JOIN public.dim_supervisores ds ON sup.codsupervisor = ds.codigo
        GROUP BY sma.codusur, dv.nome, ds.nome, ds.codigo
    ),
    final_output AS (
        SELECT jsonb_build_object(
            'quarterMonths', jsonb_build_array(
                jsonb_build_object('key', v_m1_key, 'label', v_m1_label),
                jsonb_build_object('key', v_m2_key, 'label', v_m2_label),
                jsonb_build_object('key', v_m3_key, 'label', v_m3_label)
            ),
            'sellers', COALESCE(jsonb_agg(row_to_json(st)), '[]'::jsonb)
        ) as result
        FROM seller_totals st
        WHERE st.vendedor_nome IS NOT NULL AND st.vendedor_nome != 'BALCAO' AND st.vendedor_nome != 'INATIVOS'
    )
    SELECT COALESCE(result, jsonb_build_object(
        'quarterMonths', jsonb_build_array(
            jsonb_build_object('key', v_m1_key, 'label', v_m1_label),
            jsonb_build_object('key', v_m2_key, 'label', v_m2_label),
            jsonb_build_object('key', v_m3_key, 'label', v_m3_label)
        ),
        'sellers', '[]'::jsonb
    )) INTO v_result
    FROM final_output;
    RETURN v_result;
END;
$function$
