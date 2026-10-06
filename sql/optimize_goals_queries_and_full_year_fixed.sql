-- Preserve access checks and function privileges; only replace calculation bodies.
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
    WITH supervisor_counts AS MATERIALIZED (
        SELECT codusur, codsupervisor, COUNT(*) AS sale_count
        FROM public.data_summary
        GROUP BY codusur, codsupervisor
    ), supervisor_by_seller AS (
        SELECT DISTINCT ON (codusur) codusur, codsupervisor
        FROM supervisor_counts
        ORDER BY codusur, sale_count DESC, codsupervisor
    ), raw_sales_all AS (
        SELECT 
            CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END,
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
        LEFT JOIN public.data_clients c ON c.codigo_cliente = d.codcli
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
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text IN (
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
            CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END,
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
        LEFT JOIN public.data_clients c ON c.codigo_cliente = d.codcli
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
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text IN (
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
        SELECT codusur, month_key, codfor, categoria_produto, mix_marca, codcli,
               SUM(vlvenda) AS vlvenda, SUM(totpesoliq) AS totpesoliq,
               MAX(CASE WHEN vlvenda > 0 THEN 1 ELSE 0 END) AS has_positive
        FROM raw_sales_all
        GROUP BY codusur, month_key, codfor, categoria_produto, mix_marca, codcli
    ),
    client_month_mix AS (
        SELECT 
            codusur,
            month_key,
            codcli,
            MAX(CASE WHEN mix_marca = 'CHEETOS' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_cheetos,
            MAX(CASE WHEN mix_marca = 'DORITOS' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_doritos,
            MAX(CASE WHEN mix_marca = 'FANDANGOS' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_fandangos,
            MAX(CASE WHEN mix_marca = 'RUFFLES' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_ruffles,
            MAX(CASE WHEN mix_marca = 'TORCIDA' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_torcida,
            
            MAX(CASE WHEN mix_marca = 'TODDYNHO' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_toddynho,
            MAX(CASE WHEN mix_marca = 'TODDY' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_toddy,
            MAX(CASE WHEN mix_marca = 'QUAKER' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_quaker,
            MAX(CASE WHEN mix_marca = 'KEROCOCO' AND has_positive = 1 THEN 1 ELSE 0 END) AS has_kerococo
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
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') AND has_positive = 1 THEN codcli END) AS pos_elma,
            
            -- 707
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '707' THEN vlvenda ELSE 0 END) AS fat_707,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '707' AND has_positive = 1 THEN codcli END) AS pos_707,
            
            -- 708
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '708' THEN vlvenda ELSE 0 END) AS fat_708,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '708' AND has_positive = 1 THEN codcli END) AS pos_708,
            
            -- 752
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '752' THEN vlvenda ELSE 0 END) AS fat_752,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '752' AND has_positive = 1 THEN codcli END) AS pos_752,
            
            -- TOTAL FOODS
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN vlvenda ELSE 0 END) AS fat_foods,
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN totpesoliq ELSE 0 END) AS vol_foods,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND has_positive = 1 THEN codcli END) AS pos_foods,
            
            -- TODDYNHO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%') THEN vlvenda ELSE 0 END) AS fat_toddynho,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%') AND has_positive = 1 THEN codcli END) AS pos_toddynho,
            
            -- TODDY
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY') THEN vlvenda ELSE 0 END) AS fat_toddy,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY') AND has_positive = 1 THEN codcli END) AS pos_toddy,
            
            -- QUAKER KEROCOCO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%') THEN vlvenda ELSE 0 END) AS fat_quaker_kerococo,
            COUNT(DISTINCT CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%') AND has_positive = 1 THEN codcli END) AS pos_quaker_kerococo

        FROM raw_sales
        GROUP BY codusur, month_key
    ),
    seller_totals AS (
        SELECT 
            sma.codusur,
            dv.nome AS vendedor_nome,
            CASE
                WHEN sup.codsupervisor IN ('18','21') THEN 'RÔMULO AMADO DA'
                WHEN sup.codsupervisor = '12' THEN 'TIAGO JOSÉ DE S'
                WHEN sup.codsupervisor = 'SV_AMERICANAS' THEN 'SV AMERICANAS'
                WHEN sup.codsupervisor = '8' THEN 'BALCAO'
                ELSE ds.nome
            END AS supervisor_nome,
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
        LEFT JOIN supervisor_by_seller sup ON sup.codusur = sma.codusur
        LEFT JOIN public.dim_supervisores ds ON sup.codsupervisor = ds.codigo
        GROUP BY sma.codusur, dv.nome, ds.nome, ds.codigo, sup.codsupervisor
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
        WHERE st.vendedor_nome IS NOT NULL
          AND UPPER(st.vendedor_nome) NOT LIKE 'INATIVOS%'
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
;

CREATE OR REPLACE FUNCTION public.get_metas_anuais_chart(p_ano integer, p_codsupervisor text DEFAULT NULL::text, p_codusur text DEFAULT NULL::text, p_mes_atual integer DEFAULT 12, p_categoria text DEFAULT 'Todos'::text, p_filial text DEFAULT 'Todas'::text, p_fornecedor text DEFAULT 'Todos'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_result JSONB;
    v_percentual NUMERIC;
    v_last_sale DATE;
    v_last_year INTEGER;
    v_last_month INTEGER;
    v_mes_fechado INTEGER;
BEGIN
    PERFORM private.evolution_assert_approved();
    -- Obter o percentual de crescimento para o ano
    SELECT percentual INTO v_percentual
    FROM public.metas_crescimento
    WHERE ano = p_ano;

    -- Descobrir a data da ultima venda para saber os meses fechados/abertos
    SELECT MAX(dtped::date) INTO v_last_sale FROM (
        SELECT MAX(dtped) as dtped FROM public.data_history
        UNION ALL
        SELECT MAX(dtped) as dtped FROM public.data_detailed
    ) q;
    
    IF v_last_sale IS NULL THEN
        v_last_year := EXTRACT(YEAR FROM CURRENT_DATE);
        v_last_month := EXTRACT(MONTH FROM CURRENT_DATE);
    ELSE
        v_last_year := EXTRACT(YEAR FROM v_last_sale);
        v_last_month := EXTRACT(MONTH FROM v_last_sale);
    END IF;

    IF p_ano < v_last_year THEN
        v_mes_fechado := 12;
    ELSIF p_ano > v_last_year THEN
        v_mes_fechado := 0;
    ELSE
        -- Se a última venda pertence a um mês anterior ao mês-calendário atual,
        -- esse mês já está fechado e deve entrar integralmente nos realizados.
        IF v_last_year < EXTRACT(YEAR FROM CURRENT_DATE)
           OR (v_last_year = EXTRACT(YEAR FROM CURRENT_DATE)
               AND v_last_month < EXTRACT(MONTH FROM CURRENT_DATE)) THEN
            v_mes_fechado := v_last_month;
        ELSE
            v_mes_fechado := GREATEST(v_last_month - 1, 0);
        END IF;
    END IF;

    WITH meses AS (
        SELECT generate_series(1, 12) as mes
    ),

mix_goal_raw_all AS (
        SELECT 
            CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END AS codusur,
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
        LEFT JOIN public.data_clients c ON c.codigo_cliente = d.codcli
        WHERE d.dtped >= (make_date(p_ano, 1, 1) - INTERVAL '3 months') AND d.dtped < make_date(p_ano, 12, 1)
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
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text IN (
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
            CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END AS codusur,
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
        LEFT JOIN public.data_clients c ON c.codigo_cliente = d.codcli
        WHERE d.dtped >= (make_date(p_ano, 1, 1) - INTERVAL '3 months') AND d.dtped < make_date(p_ano, 12, 1)
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
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN c.rca1
                ELSE d.codusur
            END)::text IN (
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
    mix_goal_raw AS (
        SELECT * FROM mix_goal_raw_all
    ),
    mix_goal_client_month AS (
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
        FROM mix_goal_raw
        GROUP BY codusur, month_key, codcli
    ),
    mix_goal_seller_month AS (
        SELECT
            codusur,
            month_key,
            COUNT(CASE WHEN has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1 THEN 1 END) AS mix_salty,
            COUNT(CASE WHEN has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1 THEN 1 END) AS mix_foods
        FROM mix_goal_client_month
        GROUP BY codusur, month_key
    ),
    mix_goal_seller_targets AS (
        SELECT mm.mes, jsonb_build_object(
            'vendedor_nome', dv.nome,
            'sum_mix_foods', SUM(s.mix_foods),
            'sum_mix_salty', SUM(s.mix_salty)
        ) AS value
        FROM mix_goal_seller_month s
        JOIN meses mm ON s.month_key >= to_char(make_date(p_ano, mm.mes, 1) - INTERVAL '3 months','YYYY-MM')
                     AND s.month_key < to_char(make_date(p_ano, mm.mes, 1),'YYYY-MM')
        JOIN public.dim_vendedores dv ON dv.codigo = s.codusur
        WHERE dv.nome IS NOT NULL AND UPPER(dv.nome) NOT LIKE 'INATIVOS%'
        GROUP BY mm.mes, s.codusur, dv.nome
    ),

    -- Match the table: same seller scope, saved zeros, quarterly fallback,
    -- and rounding per seller before adding supervisor/GV totals.
    metas_mix_tabela AS MATERIALIZED (
        SELECT mm.mes,
            COALESCE(SUM(FLOOR(COALESCE(sf.valor_ajuste,
                (seller.value->>'sum_mix_foods')::numeric / 3, 0) + 0.5)), 0) AS meta_foods,
            COALESCE(SUM(FLOOR(COALESCE(ss.valor_ajuste,
                (seller.value->>'sum_mix_salty')::numeric / 3, 0) + 0.5)), 0) AS meta_salty
        FROM meses mm
        LEFT JOIN mix_goal_seller_targets seller ON seller.mes = mm.mes
        LEFT JOIN public.metas_sv sf
          ON sf.ano = p_ano AND sf.mes = mm.mes
         AND sf.categoria = 'mix_foods' AND sf.metrica = 'MIX'
         AND p_fornecedor = 'Todos'
         AND UPPER(TRIM(sf.vendedor_nome)) = UPPER(TRIM(seller.value->>'vendedor_nome'))
        LEFT JOIN public.metas_sv ss
          ON ss.ano = p_ano AND ss.mes = mm.mes
         AND ss.categoria = 'mix_salty' AND ss.metrica = 'MIX'
         AND p_fornecedor = 'Todos'
         AND UPPER(TRIM(ss.vendedor_nome)) = UPPER(TRIM(seller.value->>'vendedor_nome'))
        GROUP BY mm.mes
    ),

    metas_salvas AS (
        SELECT
            m.mes,
            SUM(CASE WHEN m.metrica = 'FAT' AND (
                (p_fornecedor = 'Todos' AND m.categoria IN ('707', '708', '752', '1119_TODDYNHO', '1119_TODDY', '1119_QUAKER_KEROCOCO')) OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', '1119_QUAKER_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_fat_geral,
            SUM(CASE WHEN m.metrica = 'VOL' AND (
                (p_fornecedor = 'Todos' AND m.categoria IN ('tonelada_elma', 'tonelada_foods')) OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', '1119_QUAKER_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_vol_geral,
            SUM(CASE WHEN m.metrica = 'POS' AND (
                (p_fornecedor = 'Todos' AND m.categoria = 'pepsico_all') OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', '1119_QUAKER_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_pos_geral,
            SUM(CASE WHEN m.metrica = 'MIX' AND m.categoria IN ('mix_salty') THEN m.valor_ajuste ELSE 0 END) as meta_pos_salty,
            SUM(CASE WHEN m.metrica = 'MIX' AND m.categoria IN ('mix_foods') THEN m.valor_ajuste ELSE 0 END) as meta_pos_foods,
            -- Extrair as importadas individuais pro caso de p_categoria ser especificado (ex: CHEETOS)
            SUM(CASE WHEN m.metrica = 'FAT' AND UPPER(m.categoria) = UPPER(p_categoria) THEN m.valor_ajuste ELSE 0 END) as meta_fat_cat,
            SUM(CASE WHEN m.metrica = 'VOL' AND UPPER(m.categoria) = UPPER(p_categoria) THEN m.valor_ajuste ELSE 0 END) as meta_vol_cat,
            SUM(CASE WHEN m.metrica = 'POS' AND UPPER(m.categoria) = UPPER(p_categoria) THEN m.valor_ajuste ELSE 0 END) as meta_pos_cat
        FROM public.metas_sv m
        WHERE m.ano = p_ano
          AND EXISTS (
              SELECT 1
              FROM public.dim_vendedores dv_valid
              WHERE UPPER(TRIM(dv_valid.nome)) = UPPER(TRIM(m.vendedor_nome))
          )
          AND (p_codusur IS NULL OR p_codusur = '' OR m.vendedor_nome = p_codusur OR m.vendedor_nome IN (SELECT nome FROM public.dim_vendedores WHERE codigo = p_codusur))
          AND (p_codsupervisor IS NULL OR p_codsupervisor = '' OR m.vendedor_nome IN (
              SELECT DISTINCT COALESCE(dv.nome, dsf.codusur)
              FROM public.data_summary_frequency dsf
              LEFT JOIN public.dim_vendedores dv ON dsf.codusur = dv.codigo
              WHERE dsf.codsupervisor = p_codsupervisor
                 OR dsf.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = p_codsupervisor OR codigo = p_codsupervisor)
          ))
        GROUP BY m.mes
    ),

    base_realizado_atual AS (
        SELECT
            mes, codcli,
            SUM(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND tipovenda IN ('1', '9') THEN vlvenda ELSE 0 END) as vlvenda_total,
            SUM(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND tipovenda NOT IN ('5', '11')
          AND (p_categoria = 'Todos' OR categorias ? UPPER(p_categoria))
           THEN peso ELSE 0 END) as peso_total,
            MAX(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND vlvenda > 0 THEN 1 ELSE 0 END) as is_positivado,
            MAX(has_cheetos) as has_cheetos, MAX(has_doritos) as has_doritos, MAX(has_fandangos) as has_fandangos, MAX(has_ruffles) as has_ruffles, MAX(has_torcida) as has_torcida,
            MAX(has_toddynho) as has_toddynho, MAX(has_toddy) as has_toddy, MAX(has_quaker) as has_quaker, MAX(has_kerococo) as has_kerococo
        FROM public.data_summary_frequency
        WHERE ano = p_ano
          AND (
              p_codusur IS NULL OR p_codusur = ''
              OR codusur = p_codusur
              OR codusur IN (
                  SELECT codigo
                  FROM public.dim_vendedores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codusur))
              )
          )
          AND (
              p_codsupervisor IS NULL OR p_codsupervisor = ''
              OR codsupervisor = p_codsupervisor
              OR codsupervisor IN (
                  SELECT codigo
                  FROM public.dim_supervisores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codsupervisor))
              )
          )
          AND (p_filial = 'Todas' OR filial = p_filial)
          AND (
              p_fornecedor = 'Todos'
              OR codfor::text = p_fornecedor
              OR LTRIM(codfor::text, '0') = p_fornecedor
              OR (p_fornecedor = '1119' AND codfor::text LIKE '1119_%')
              OR (
                  p_fornecedor = '1119_QUAKER_KEROCOCO'
                  AND LTRIM(codfor::text, '0') IN ('1119_QUAKER', '1119_KEROCOCO')
              )
          )
          AND tipovenda NOT IN ('5', '11')
          AND (p_categoria = 'Todos' OR categorias ? UPPER(p_categoria))
          
        GROUP BY mes, codcli
    ),
    
    base_realizado_anterior AS (
        SELECT
            mes, codcli,
            SUM(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND tipovenda IN ('1', '9') THEN vlvenda ELSE 0 END) as vlvenda_total,
            SUM(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND tipovenda NOT IN ('5', '11')
          AND (p_categoria = 'Todos' OR categorias ? UPPER(p_categoria))
           THEN peso ELSE 0 END) as peso_total,
            MAX(CASE WHEN (LTRIM(codfor::text, '0') IN ('707', '708', '752', '1119') OR LTRIM(codfor::text, '0') LIKE '1119_%') AND vlvenda > 0 THEN 1 ELSE 0 END) as is_positivado,
            MAX(has_cheetos) as has_cheetos, MAX(has_doritos) as has_doritos, MAX(has_fandangos) as has_fandangos, MAX(has_ruffles) as has_ruffles, MAX(has_torcida) as has_torcida,
            MAX(has_toddynho) as has_toddynho, MAX(has_toddy) as has_toddy, MAX(has_quaker) as has_quaker, MAX(has_kerococo) as has_kerococo
        FROM public.data_summary_frequency
        WHERE ano = p_ano - 1
          AND (
              p_codusur IS NULL OR p_codusur = ''
              OR codusur = p_codusur
              OR codusur IN (
                  SELECT codigo
                  FROM public.dim_vendedores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codusur))
              )
          )
          AND (
              p_codsupervisor IS NULL OR p_codsupervisor = ''
              OR codsupervisor = p_codsupervisor
              OR codsupervisor IN (
                  SELECT codigo
                  FROM public.dim_supervisores
                  WHERE UPPER(TRIM(nome)) = UPPER(TRIM(p_codsupervisor))
              )
              -- Rômulo mudou de código de supervisão ao longo do histórico:
              -- 18 no período anterior e 21 no período atual. Ao filtrar pelo
              -- supervisor consolidado, o ano anterior precisa considerar ambos.
              OR (
                  UPPER(TRIM(p_codsupervisor)) = UPPER('RÔMULO AMADO DA')
                  AND codsupervisor IN ('18','21')
              )
          )
          AND (p_filial = 'Todas' OR filial = p_filial)
          AND (
              p_fornecedor = 'Todos'
              OR codfor::text = p_fornecedor
              OR LTRIM(codfor::text, '0') = p_fornecedor
              OR (p_fornecedor = '1119' AND codfor::text LIKE '1119_%')
              OR (
                  p_fornecedor = '1119_QUAKER_KEROCOCO'
                  AND LTRIM(codfor::text, '0') IN ('1119_QUAKER', '1119_KEROCOCO')
              )
          )
          AND tipovenda NOT IN ('5', '11')
          AND (p_categoria = 'Todos' OR categorias ? UPPER(p_categoria))
          
        GROUP BY mes, codcli
    ),

    agregado_realizado_atual AS (
        SELECT
            mes,
            SUM(vlvenda_total) as real_fat_geral,
            SUM(peso_total) as real_vol_geral,
            COUNT(DISTINCT CASE WHEN is_positivado = 1 THEN codcli END) as real_pos_geral,
            COUNT(DISTINCT CASE WHEN COALESCE(has_cheetos,0)=1 AND COALESCE(has_doritos,0)=1 AND COALESCE(has_fandangos,0)=1 AND COALESCE(has_ruffles,0)=1 AND COALESCE(has_torcida,0)=1 THEN codcli END) as real_pos_salty,
            COUNT(DISTINCT CASE WHEN COALESCE(has_toddynho,0)=1 AND COALESCE(has_toddy,0)=1 AND COALESCE(has_quaker,0)=1 AND COALESCE(has_kerococo,0)=1 THEN codcli END) as real_pos_foods
        FROM base_realizado_atual
        GROUP BY mes
    ),
    
    agregado_realizado_anterior AS (
        SELECT
            mes,
            SUM(vlvenda_total) as real_fat_geral,
            SUM(peso_total) as real_vol_geral,
            COUNT(DISTINCT CASE WHEN is_positivado = 1 THEN codcli END) as real_pos_geral,
            COUNT(DISTINCT CASE WHEN COALESCE(has_cheetos,0)=1 AND COALESCE(has_doritos,0)=1 AND COALESCE(has_fandangos,0)=1 AND COALESCE(has_ruffles,0)=1 AND COALESCE(has_torcida,0)=1 THEN codcli END) as real_pos_salty,
            COUNT(DISTINCT CASE WHEN COALESCE(has_toddynho,0)=1 AND COALESCE(has_toddy,0)=1 AND COALESCE(has_quaker,0)=1 AND COALESCE(has_kerococo,0)=1 THEN codcli END) as real_pos_foods
        FROM base_realizado_anterior
        GROUP BY mes
    ),
    
    totais_anterior AS (
        SELECT 
            COALESCE(SUM(real_fat_geral), 0) as total_fat,
            COALESCE(SUM(real_vol_geral), 0) as total_vol,
            (SELECT COUNT(DISTINCT CASE WHEN is_positivado = 1 THEN codcli END) FROM base_realizado_anterior) as total_pos_geral,
            (SELECT COUNT(DISTINCT CASE WHEN COALESCE(has_cheetos,0)=1 AND COALESCE(has_doritos,0)=1 AND COALESCE(has_fandangos,0)=1 AND COALESCE(has_ruffles,0)=1 AND COALESCE(has_torcida,0)=1 THEN codcli END) FROM base_realizado_anterior) as total_pos_salty,
            (SELECT COUNT(DISTINCT CASE WHEN COALESCE(has_toddynho,0)=1 AND COALESCE(has_toddy,0)=1 AND COALESCE(has_quaker,0)=1 AND COALESCE(has_kerococo,0)=1 THEN codcli END) FROM base_realizado_anterior) as total_pos_foods,
            COALESCE(SUM(real_pos_geral), 0) as total_sum_pos_geral,
            COALESCE(SUM(real_pos_salty), 0) as total_sum_pos_salty,
            COALESCE(SUM(real_pos_foods), 0) as total_sum_pos_foods
        FROM agregado_realizado_anterior
    ),
    
    pesos_mes_anterior AS (
        SELECT 
            m.mes,
            CASE WHEN t.total_fat > 0 THEN COALESCE(a.real_fat_geral, 0) / t.total_fat ELSE 1.0/12.0 END as peso_fat,
            CASE WHEN t.total_vol > 0 THEN COALESCE(a.real_vol_geral, 0) / t.total_vol ELSE 1.0/12.0 END as peso_vol,
            CASE WHEN t.total_sum_pos_geral > 0 THEN COALESCE(a.real_pos_geral, 0)::NUMERIC / t.total_sum_pos_geral ELSE 1.0/12.0 END as peso_pos,
            CASE WHEN t.total_sum_pos_salty > 0 THEN COALESCE(a.real_pos_salty, 0)::NUMERIC / t.total_sum_pos_salty ELSE 1.0/12.0 END as peso_salty,
            CASE WHEN t.total_sum_pos_foods > 0 THEN COALESCE(a.real_pos_foods, 0)::NUMERIC / t.total_sum_pos_foods ELSE 1.0/12.0 END as peso_foods
        FROM meses m
        LEFT JOIN agregado_realizado_anterior a ON a.mes = m.mes
        CROSS JOIN totais_anterior t
    ),
    
    realizado_meses_fechados AS (
        SELECT 
            COALESCE(SUM(real_fat_geral), 0) as fat_realizado_fechado,
            COALESCE(SUM(real_vol_geral), 0) as vol_realizado_fechado,
            -- Para POSitização, o realizado até agora é simplesmente a soma dos já fechados (como base para rateio), 
            -- embora o correto seja olhar os clientes distintos do ano.
            -- Para simplicidade matemática de rateio, somamos a quantidade mensal dos meses fechados:
            COALESCE(SUM(real_pos_geral), 0) as pos_geral_realizado_fechado,
            COALESCE(SUM(real_pos_salty), 0) as pos_salty_realizado_fechado,
            COALESCE(SUM(real_pos_foods), 0) as pos_foods_realizado_fechado
        FROM agregado_realizado_atual
        WHERE mes <= v_mes_fechado
    ),
    
    -- Reserve imported targets; distribute only across months without an override.
    pesos_restantes_abertos AS (
        SELECT
            SUM(CASE WHEN pm.mes > v_mes_fechado THEN pm.peso_fat ELSE 0 END) as soma_peso_fat_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado THEN pm.peso_vol ELSE 0 END) as soma_peso_vol_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado AND COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END),0) <= 0 THEN pm.peso_pos ELSE 0 END) as soma_peso_pos_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado THEN GREATEST(COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END),0),0) ELSE 0 END) as metas_salvas_pos_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado AND COALESCE(ms.meta_pos_salty,0) <= 0 THEN pm.peso_salty ELSE 0 END) as soma_peso_salty_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado THEN GREATEST(COALESCE(ms.meta_pos_salty,0),0) ELSE 0 END) as metas_salvas_salty_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado AND COALESCE(ms.meta_pos_foods,0) <= 0 THEN pm.peso_foods ELSE 0 END) as soma_peso_foods_restante,
            SUM(CASE WHEN pm.mes > v_mes_fechado THEN GREATEST(COALESCE(ms.meta_pos_foods,0),0) ELSE 0 END) as metas_salvas_foods_restante
        FROM pesos_mes_anterior pm
        LEFT JOIN metas_salvas ms ON ms.mes = pm.mes
    ),

    -- Quantos clientes únicos realmente positivaram no ANO INTEIRO até agora? (Isso evita somar repetições)
    realizado_anual_unicos AS (
        SELECT
            COUNT(DISTINCT CASE WHEN is_positivado = 1 THEN codcli END) as ano_real_pos_geral,
            COUNT(DISTINCT CASE WHEN COALESCE(has_cheetos,0)=1 AND COALESCE(has_doritos,0)=1 AND COALESCE(has_fandangos,0)=1 AND COALESCE(has_ruffles,0)=1 AND COALESCE(has_torcida,0)=1 THEN codcli END) as ano_real_pos_salty,
            COUNT(DISTINCT CASE WHEN COALESCE(has_toddynho,0)=1 AND COALESCE(has_toddy,0)=1 AND COALESCE(has_quaker,0)=1 AND COALESCE(has_kerococo,0)=1 THEN codcli END) as ano_real_pos_foods
        FROM base_realizado_atual
    ),

    chart_data AS (
                SELECT
            m.mes,
            
            -- Faturamento (Fat)
            COALESCE(ra.real_fat_geral, 0) as kpi_realizado_anterior_fat,
            COALESCE(r.real_fat_geral, 0) as kpi_realizado_atual_fat,
            
            CASE 
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_fat_geral, 0)
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_fat_restante > 0 THEN
                            GREATEST(0, (t.total_fat * (1 + (v_percentual / 100.0)) - r_fechado.fat_realizado_fechado)) * (pm.peso_fat / pr.soma_peso_fat_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_fat,

            -- Meta Estimada Fixa: preserva a meta originalmente projetada do mês
            -- mesmo depois que o mês fecha. Só é exposta para meses fechados.
            CASE
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END) > 0
                    THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END)
                WHEN v_percentual IS NULL THEN NULL
                ELSE (t.total_fat * (1 + (v_percentual / 100.0))) * pm.peso_fat
            END as kpi_meta_fixa_fat,

            -- Tonelada (Vol)
            COALESCE(ra.real_vol_geral, 0) as kpi_realizado_anterior_vol,
            COALESCE(r.real_vol_geral, 0) as kpi_realizado_atual_vol,
            
            CASE 
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_vol_geral, 0)
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END) > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_vol_restante > 0 THEN
                            GREATEST(0, (t.total_vol * (1 + (v_percentual / 100.0)) - r_fechado.vol_realizado_fechado)) * (pm.peso_vol / pr.soma_peso_vol_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_vol,

            CASE
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END) > 0
                    THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END)
                WHEN v_percentual IS NULL THEN NULL
                ELSE (t.total_vol * (1 + (v_percentual / 100.0))) * pm.peso_vol
            END as kpi_meta_fixa_vol,

            -- Positicação Geral
            COALESCE(ra.real_pos_geral, 0) as kpi_realizado_anterior_pos,
            COALESCE(r.real_pos_geral, 0) as kpi_realizado_atual_pos,
            CASE 
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_geral, 0)
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END) > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_pos_restante > 0 THEN
                            GREATEST(
                                t.total_sum_pos_geral * (1 + (v_percentual / 100.0)) * pr.soma_peso_pos_restante,
                                t.total_sum_pos_geral * (1 + (v_percentual / 100.0)) - r_fechado.pos_geral_realizado_fechado - pr.metas_salvas_pos_restante,
                                0
                            ) * (pm.peso_pos / pr.soma_peso_pos_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_pos,

            CASE
                WHEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END) > 0
                    THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END)
                WHEN v_percentual IS NULL THEN NULL
                ELSE (t.total_sum_pos_geral * (1 + (v_percentual / 100.0))) * pm.peso_pos
            END as kpi_meta_fixa_pos,

            -- Positivação Salty
            COALESCE(ra.real_pos_salty, 0) as kpi_realizado_anterior_salty,
            COALESCE(r.real_pos_salty, 0) as kpi_realizado_atual_salty,
            CASE 
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_salty, 0)
                WHEN ms.meta_pos_salty > 0 THEN ms.meta_pos_salty
                WHEN v_percentual IS NULL THEN COALESCE(ms.meta_pos_salty, 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_salty_restante > 0 THEN
                            GREATEST(
                                t.total_sum_pos_salty * (1 + (v_percentual / 100.0)) * pr.soma_peso_salty_restante,
                                t.total_sum_pos_salty * (1 + (v_percentual / 100.0)) - r_fechado.pos_salty_realizado_fechado - pr.metas_salvas_salty_restante,
                                0
                            ) * (pm.peso_salty / pr.soma_peso_salty_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_salty,

            COALESCE(mt.meta_salty, 0) as kpi_meta_fixa_salty,

            -- Positivação Foods
            COALESCE(ra.real_pos_foods, 0) as kpi_realizado_anterior_foods,
            COALESCE(r.real_pos_foods, 0) as kpi_realizado_atual_foods,
            CASE 
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_foods, 0)
                WHEN ms.meta_pos_foods > 0 THEN ms.meta_pos_foods
                WHEN v_percentual IS NULL THEN COALESCE(ms.meta_pos_foods, 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_foods_restante > 0 THEN
                            GREATEST(
                                t.total_sum_pos_foods * (1 + (v_percentual / 100.0)) * pr.soma_peso_foods_restante,
                                t.total_sum_pos_foods * (1 + (v_percentual / 100.0)) - r_fechado.pos_foods_realizado_fechado - pr.metas_salvas_foods_restante,
                                0
                            ) * (pm.peso_foods / pr.soma_peso_foods_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_foods,

            COALESCE(mt.meta_foods, 0) as kpi_meta_fixa_foods

        FROM meses m
        LEFT JOIN agregado_realizado_atual r ON r.mes = m.mes
        LEFT JOIN agregado_realizado_anterior ra ON ra.mes = m.mes
        LEFT JOIN metas_salvas ms ON ms.mes = m.mes
        LEFT JOIN metas_mix_tabela mt ON mt.mes = m.mes
        LEFT JOIN pesos_mes_anterior pm ON pm.mes = m.mes
        CROSS JOIN totais_anterior t
        CROSS JOIN pesos_restantes_abertos pr
        CROSS JOIN realizado_meses_fechados r_fechado
        CROSS JOIN realizado_anual_unicos r_ano
        ORDER BY m.mes
    )

    SELECT jsonb_build_object(
        'chart_data', COALESCE(jsonb_agg(row_to_json(chart_data)), '[]'::jsonb),
        'percentual_crescimento', v_percentual,
        'mes_fechado', v_mes_fechado,
        'kpi_total_anterior_fat', (SELECT total_fat FROM totais_anterior),
        'kpi_total_anterior_vol', (SELECT total_vol FROM totais_anterior),
        'kpi_total_atual_fat', (SELECT COALESCE(SUM(real_fat_geral), 0) FROM agregado_realizado_atual),
        'kpi_total_atual_vol', (SELECT COALESCE(SUM(real_vol_geral), 0) FROM agregado_realizado_atual),
        'kpi_total_anterior_pos', (SELECT total_pos_geral FROM totais_anterior),
        'kpi_total_atual_pos', (SELECT ano_real_pos_geral FROM realizado_anual_unicos),
        'kpi_total_anterior_salty', (SELECT total_pos_salty FROM totais_anterior),
        'kpi_total_atual_salty', (SELECT ano_real_pos_salty FROM realizado_anual_unicos),
        'kpi_total_anterior_foods', (SELECT total_pos_foods FROM totais_anterior),
        'kpi_total_atual_foods', (SELECT ano_real_pos_foods FROM realizado_anual_unicos)
    ) INTO v_result
    FROM chart_data;

    RETURN v_result;
END;
$function$
;
