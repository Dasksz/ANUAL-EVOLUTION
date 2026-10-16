-- Recompute each seller's supervisor from the most recent dated sales assignment.
-- All historical sales are then attributed to that current assignment automatically.

CREATE OR REPLACE FUNCTION private.evolution_goals_supervisor_by_seller()
RETURNS TABLE(codusur text, codsupervisor text)
LANGUAGE sql
STABLE
SET search_path = ''
AS $function$
    WITH raw_assignments AS MATERIALIZED (
        SELECT
            CASE d.codusur WHEN '53' THEN 'BALCAO_SP'
                           WHEN '1001' THEN 'AMERICANAS'
                           ELSE d.codusur
            END AS codusur,
            d.codsupervisor,
            d.dtped
        FROM public.data_detailed_current d
        WHERE d.codusur IS NOT NULL
          AND d.codsupervisor IS NOT NULL
          AND d.dtped IS NOT NULL

        UNION ALL

        SELECT
            CASE d.codusur WHEN '53' THEN 'BALCAO_SP'
                           WHEN '1001' THEN 'AMERICANAS'
                           ELSE d.codusur
            END AS codusur,
            d.codsupervisor,
            d.dtped
        FROM public.data_history_current d
        WHERE d.codusur IS NOT NULL
          AND d.codsupervisor IS NOT NULL
          AND d.dtped IS NOT NULL
    ),
    latest_assignments AS (
        SELECT codusur, codsupervisor, dtped
        FROM (
            SELECT
                codusur,
                codsupervisor,
                dtped,
                max(dtped) OVER (PARTITION BY codusur) AS latest_dtped
            FROM raw_assignments
        ) dated
        WHERE dtped = latest_dtped
    ),
    supervisor_counts AS (
        SELECT codusur, codsupervisor, count(*) AS assignment_count
        FROM latest_assignments
        GROUP BY codusur, codsupervisor
    )
    SELECT DISTINCT ON (codusur) codusur, codsupervisor
    FROM supervisor_counts
    ORDER BY codusur, assignment_count DESC, codsupervisor;
$function$;

REVOKE ALL ON FUNCTION private.evolution_goals_supervisor_by_seller() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.evolution_goals_sales(p_from date, p_to date, p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
 RETURNS TABLE(codusur text, codsupervisor text, month_key text, codfor text, categoria_produto text, mix_marca text, vlvenda numeric, totpesoliq numeric, codcli text, tipovenda text, filial text)
 LANGUAGE sql
 STABLE
AS $function$
 WITH raw AS (
   SELECT d.codusur,d.codsupervisor,d.dtped,d.codfor,d.produto,d.vlvenda,d.totpesoliq,d.codcli,d.tipovenda,d.filial
   FROM public.data_detailed_current d WHERE d.dtped>=p_from AND d.dtped<p_to
   UNION ALL
   SELECT d.codusur,d.codsupervisor,d.dtped,d.codfor,d.produto,d.vlvenda,d.totpesoliq,d.codcli,d.tipovenda,d.filial
   FROM public.data_history_current d WHERE d.dtped>=p_from AND d.dtped<p_to
 ), supervisor_by_seller AS MATERIALIZED (
   SELECT * FROM private.evolution_goals_supervisor_by_seller()
 ), f AS MATERIALIZED (
   SELECT private.evolution_goals_values(p_filiais) fi,
          private.evolution_goals_values(p_fornecedores) fo,
          private.evolution_goals_values(p_supervisores) su,
          private.evolution_goals_values(p_vendedores) ve,
          private.evolution_goals_values(p_categorias) ca
 )
 SELECT d.codusur::text,COALESCE(sbs.codsupervisor,d.codsupervisor)::text,to_char(d.dtped,'YYYY-MM'),ltrim(d.codfor::text,'0'),
        upper(dp.categoria_produto),upper(dp.mix_marca),d.vlvenda::numeric,d.totpesoliq::numeric,
        d.codcli::text,d.tipovenda::text,d.filial::text
 FROM raw d
 LEFT JOIN supervisor_by_seller sbs
   ON sbs.codusur=CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
 LEFT JOIN public.dim_produtos dp ON dp.codigo=d.produto
 LEFT JOIN public.dim_vendedores dv ON dv.codigo=d.codusur
 LEFT JOIN public.dim_supervisores ds ON ds.codigo=COALESCE(sbs.codsupervisor,d.codsupervisor)
 CROSS JOIN f
 WHERE (cardinality(f.fi)=0 OR upper(d.filial::text)=ANY(f.fi))
   AND (cardinality(f.ve)=0 OR upper(d.codusur::text)=ANY(f.ve) OR upper(trim(dv.nome))=ANY(f.ve))
   AND (cardinality(f.su)=0 OR upper(COALESCE(sbs.codsupervisor,d.codsupervisor)::text)=ANY(f.su)
        OR upper(trim(ds.nome))=ANY(f.su))
   AND (cardinality(f.ca)=0 OR upper(dp.categoria_produto)=ANY(f.ca) OR upper(dp.mix_marca)=ANY(f.ca))
   AND (cardinality(f.fo)=0 OR ltrim(d.codfor::text,'0')=ANY(f.fo)
        OR (ltrim(d.codfor::text,'0')='1119' AND EXISTS(
          SELECT 1 FROM unnest(f.fo) selected WHERE
            selected='1119'
            OR (selected='1119_QUAKER_KEROCOCO' AND (upper(dp.mix_marca) IN ('QUAKER','KEROCOCO') OR upper(dp.categoria_produto) LIKE '%QUAKER%' OR upper(dp.categoria_produto) LIKE '%KEROCOCO%'))
            OR (selected='1119_TODDYNHO' AND (upper(dp.mix_marca)='TODDYNHO' OR upper(dp.categoria_produto) LIKE '%TODDYNHO%' OR upper(dp.categoria_produto) LIKE '%TODYNHO%'))
            OR (selected='1119_TODDY' AND (upper(dp.mix_marca)='TODDY' OR upper(dp.categoria_produto)='TODDY' OR upper(dp.categoria_produto) LIKE '%TODDY %'))
            OR (selected='1119_QUAKER' AND (upper(dp.mix_marca)='QUAKER' OR upper(dp.categoria_produto) LIKE '%QUAKER%'))
            OR (selected='1119_KEROCOCO' AND (upper(dp.mix_marca)='KEROCOCO' OR upper(dp.categoria_produto) LIKE '%KEROCOCO%'))
        )));
$function$;


CREATE OR REPLACE FUNCTION private.evolution_goals_base(p_ano integer, p_mes integer, p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
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

    WITH supervisor_by_seller AS MATERIALIZED (
        SELECT * FROM private.evolution_goals_supervisor_by_seller()
    ), raw_sales_all AS (
      SELECT codusur,month_key,codfor,categoria_produto,mix_marca,vlvenda,totpesoliq,codcli,tipovenda
      FROM private.evolution_goals_sales(v_start_date,v_date,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias)
      WHERE tipovenda IN ('1','9')
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
        -- Attribute the seller to the supervisor on their latest dated sales records.
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
