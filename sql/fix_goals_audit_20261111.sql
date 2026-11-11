-- Update the verified live readers. No change to sales, source targets or client quotas.
-- Canonical commercial groups; overlapping aliases must not split a single POS scope.
CREATE OR REPLACE FUNCTION private.evolution_goals_canonical_suppliers(a text[]) RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 WITH groups AS (
   SELECT DISTINCT CASE WHEN x IN ('1119_QUAKER','1119_KEROCOCO') THEN '1119_QUAKER_KEROCOCO' ELSE x END AS x
   FROM unnest(private.evolution_goals_values(a)) t(x)
 ), normalized AS (
   SELECT coalesce(array_agg(x ORDER BY x) FILTER (WHERE NOT (
      x LIKE '1119_%' AND EXISTS(SELECT 1 FROM groups WHERE x='1119'))),'{}'::text[]) a
   FROM groups
 )
 SELECT CASE WHEN a @> ARRAY['707','708','752'] AND
   (a @> ARRAY['1119'] OR a @> ARRAY['1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'])
 THEN '{}'::text[] ELSE a END FROM normalized;
$$;
REVOKE ALL ON FUNCTION private.evolution_goals_canonical_suppliers(text[]) FROM PUBLIC,anon,authenticated;
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
      SELECT codusur,codsupervisor,month_key,codfor,categoria_produto,mix_marca,vlvenda,totpesoliq,codcli,tipovenda
      FROM private.evolution_goals_sales(v_start_date,v_date,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias)
      WHERE tipovenda NOT IN ('5','11')
    ),
    raw_sales AS (
        SELECT codusur, month_key, codfor, categoria_produto, mix_marca, codcli,
               SUM(vlvenda) FILTER (WHERE tipovenda IN ('1','9')) AS vlvenda,
               SUM(totpesoliq) FILTER (WHERE tipovenda IN ('1','9')) AS totpesoliq,
               SUM(vlvenda) AS net_pos,
               MAX(CASE WHEN vlvenda > 0 AND tipovenda IN ('1','9') THEN 1 ELSE 0 END) AS has_positive
        FROM raw_sales_all
        GROUP BY codusur, month_key, codfor, categoria_produto, mix_marca, codcli
    ), seller_client_month_net AS (
        SELECT codusur, month_key, codcli,
            SUM(net_pos) AS net_geral,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') IN ('707', '708', '752')),0) AS net_elma,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '707'),0) AS net_707,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '708'),0) AS net_708,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '752'),0) AS net_752,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '1119'),0) AS net_foods,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%')),0) AS net_toddynho,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY')),0) AS net_toddy,
            COALESCE(SUM(net_pos) FILTER (WHERE LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%')),0) AS net_quaker_kerococo
        FROM raw_sales
        WHERE NULLIF(btrim(codcli),'') IS NOT NULL
        GROUP BY codusur,month_key,codcli
    ), scoped_client_month_pos AS (
        -- The client qualifies once across the scope. Assign that count to the
        -- seller with the largest contribution when special portfolios overlap.
        SELECT s.codusur,s.month_key,s.codcli,v.metric,
               sum(v.net) OVER (PARTITION BY s.month_key,s.codcli,v.metric) AS scoped_net,
               row_number() OVER (PARTITION BY s.month_key,s.codcli,v.metric
                                  ORDER BY v.net DESC,s.codusur NULLS LAST) AS priority
        FROM seller_client_month_net s
        CROSS JOIN LATERAL (VALUES ('geral',s.net_geral), ('elma',s.net_elma), ('707',s.net_707), ('708',s.net_708), ('752',s.net_752), ('foods',s.net_foods), ('toddynho',s.net_toddynho), ('toddy',s.net_toddy), ('quaker_kerococo',s.net_quaker_kerococo)) v(metric,net)
    ), client_month_pos AS (
        SELECT codusur,month_key,codcli,max((metric='geral')::integer) AS pos_geral, max((metric='elma')::integer) AS pos_elma, max((metric='707')::integer) AS pos_707, max((metric='708')::integer) AS pos_708, max((metric='752')::integer) AS pos_752, max((metric='foods')::integer) AS pos_foods, max((metric='toddynho')::integer) AS pos_toddynho, max((metric='toddy')::integer) AS pos_toddy, max((metric='quaker_kerococo')::integer) AS pos_quaker_kerococo
        FROM scoped_client_month_pos WHERE scoped_net>=1 AND priority=1
        GROUP BY codusur,month_key,codcli
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
            COUNT(DISTINCT CASE WHEN cp.pos_geral=1 THEN raw_sales.codcli END) AS pos_geral,
            
            -- TOTAL ELMA
            SUM(CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN vlvenda ELSE 0 END) AS fat_elma,
            SUM(CASE WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN totpesoliq ELSE 0 END) AS vol_elma,
            COUNT(DISTINCT CASE WHEN cp.pos_elma=1 THEN raw_sales.codcli END) AS pos_elma,
            
            -- 707
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '707' THEN vlvenda ELSE 0 END) AS fat_707,
            COUNT(DISTINCT CASE WHEN cp.pos_707=1 THEN raw_sales.codcli END) AS pos_707,
            
            -- 708
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '708' THEN vlvenda ELSE 0 END) AS fat_708,
            COUNT(DISTINCT CASE WHEN cp.pos_708=1 THEN raw_sales.codcli END) AS pos_708,
            
            -- 752
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '752' THEN vlvenda ELSE 0 END) AS fat_752,
            COUNT(DISTINCT CASE WHEN cp.pos_752=1 THEN raw_sales.codcli END) AS pos_752,
            
            -- TOTAL FOODS
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN vlvenda ELSE 0 END) AS fat_foods,
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' THEN totpesoliq ELSE 0 END) AS vol_foods,
            COUNT(DISTINCT CASE WHEN cp.pos_foods=1 THEN raw_sales.codcli END) AS pos_foods,
            
            -- TODDYNHO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDYNHO%' OR categoria_produto ILIKE '%TODYNHO%') THEN vlvenda ELSE 0 END) AS fat_toddynho,
            COUNT(DISTINCT CASE WHEN cp.pos_toddynho=1 THEN raw_sales.codcli END) AS pos_toddynho,
            
            -- TODDY
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%TODDY %' OR categoria_produto = 'TODDY') THEN vlvenda ELSE 0 END) AS fat_toddy,
            COUNT(DISTINCT CASE WHEN cp.pos_toddy=1 THEN raw_sales.codcli END) AS pos_toddy,
            
            -- QUAKER KEROCOCO
            SUM(CASE WHEN LTRIM(codfor::text, '0') = '1119' AND (categoria_produto ILIKE '%QUAKER%' OR categoria_produto ILIKE '%KEROCOCO%') THEN vlvenda ELSE 0 END) AS fat_quaker_kerococo,
            COUNT(DISTINCT CASE WHEN cp.pos_quaker_kerococo=1 THEN raw_sales.codcli END) AS pos_quaker_kerococo

        FROM raw_sales
        LEFT JOIN client_month_pos cp USING(codusur,month_key,codcli)
        GROUP BY codusur, month_key
    ), historical_parents AS (
        SELECT codusur, CASE WHEN count(DISTINCT codsupervisor)=1 THEN min(codsupervisor) END AS code
        FROM raw_sales_all GROUP BY codusur
    ), seller_totals AS (
        SELECT 
            sma.codusur,
            dv.nome AS vendedor_nome,
            CASE
                WHEN coalesce(sup.codsupervisor,hp.code) IN ('18','21') THEN 'RÔMULO AMADO DA'
                WHEN coalesce(sup.codsupervisor,hp.code) = '12' THEN 'TIAGO JOSÉ DE S'
                WHEN coalesce(sup.codsupervisor,hp.code) = 'SV_AMERICANAS' THEN 'SV AMERICANAS'
                WHEN coalesce(sup.codsupervisor,hp.code) = '8' THEN 'BALCAO'
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
        LEFT JOIN historical_parents hp ON hp.codusur = sma.codusur
        LEFT JOIN public.dim_supervisores ds ON coalesce(sup.codsupervisor,hp.code) = ds.codigo
        GROUP BY sma.codusur, dv.nome, ds.nome, ds.codigo, coalesce(sup.codsupervisor,hp.code)
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
$function$;

CREATE OR REPLACE FUNCTION private.evolution_goals_chart(p_ano integer, p_mes_atual integer DEFAULT 12, p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_result JSONB;
    p_categoria text := 'Todos';
    p_fornecedor text := 'Todos';
    v_percentual NUMERIC;
    v_last_sale DATE;
    v_last_year INTEGER;
    v_last_month INTEGER;
    v_mes_fechado INTEGER;
    v_has_supplier BOOLEAN := false;
    v_has_elma BOOLEAN := false;
    v_has_foods BOOLEAN := false;
    v_pos_supported BOOLEAN;
BEGIN
    PERFORM private.evolution_assert_approved();
    v_pos_supported := cardinality(p_fornecedores) <= 1;
    v_has_supplier := cardinality(p_fornecedores) > 0;
    v_has_elma := p_fornecedores && ARRAY['707','708','752']::text[];
    v_has_foods := p_fornecedores && ARRAY['1119','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO','1119_QUAKER','1119_KEROCOCO']::text[];
    -- Obter o percentual de crescimento para o ano
    SELECT percentual INTO v_percentual
    FROM public.metas_crescimento
    WHERE ano = p_ano;

    -- Descobrir a data da ultima venda para saber os meses fechados/abertos
    SELECT MAX(dtped::date) INTO v_last_sale FROM (
        SELECT MAX(dtped) as dtped FROM public.data_history_current
        UNION ALL
        SELECT MAX(dtped) as dtped FROM public.data_detailed_current
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

    raw_scoped AS MATERIALIZED (
     SELECT * FROM private.evolution_goals_sales(make_date(p_ano-1,1,1),make_date(p_ano+1,1,1),p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias)
    ), target_rows AS MATERIALIZED (
      SELECT jsonb_build_object('mes',months.mes,'codusur',e->>'codigo','categoria',e->>'categoria',
        'metrica',e->>'metrica','valor_ajuste',e->'valor') m
      FROM (SELECT DISTINCT mes FROM private.evolution_official_targets WHERE ano=p_ano) months
      CROSS JOIN LATERAL jsonb_array_elements(private.evolution_dashboard_targets(p_ano,months.mes,
        jsonb_build_object('p_filial',p_filiais,'p_fornecedor',p_fornecedores,'p_supervisor',p_supervisores,
        'p_vendedor',p_vendedores,'p_categoria',p_categorias))) e
    ), targets AS (
     SELECT m, (m->>'mes')::integer mes,(m->>'metrica') metric,m->>'categoria' cat,(m->>'valor_ajuste')::numeric value,
     NOT EXISTS (SELECT 1 FROM target_rows t WHERE t.m->>'codusur'=r.m->>'codusur' AND t.m->>'mes'=r.m->>'mes'
      AND t.m->>'metrica'=r.m->>'metrica' AND t.m->>'categoria'='pepsico_all' AND (t.m->>'valor_ajuste') IS NOT NULL) no_total
     FROM target_rows r WHERE (m->>'valor_ajuste') IS NOT NULL
    ), metas_salvas AS (
     SELECT mes,
     count(*) FILTER(WHERE metric='FAT' AND (cat='pepsico_all' OR (no_total AND cat IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')))) saved_fat_count,
     count(*) FILTER(WHERE metric='FAT' AND (cat=ANY(p_fornecedores) OR ('1119'=ANY(p_fornecedores) AND cat LIKE '1119_%') OR (cat='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO']))) saved_fat_supplier_count,
     count(*) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods')))) saved_vol_count,
     count(*) FILTER(WHERE metric='VOL' AND cat='tonelada_elma') saved_vol_elma_count,
     count(*) FILTER(WHERE metric='VOL' AND cat='tonelada_foods') saved_vol_foods_count,
     count(*) FILTER(WHERE metric='POS') saved_pos_count,
     count(*) FILTER(WHERE metric='MIX' AND cat='mix_salty') saved_salty_count,
     count(*) FILTER(WHERE metric='MIX' AND cat='mix_foods') saved_foods_count,
     sum(value) FILTER(WHERE metric='FAT' AND (cat='pepsico_all' OR (no_total AND cat IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')))) meta_fat_geral,
     CASE WHEN v_has_supplier AND count(*) FILTER(WHERE metric='FAT' AND (cat=ANY(p_fornecedores) OR ('1119'=ANY(p_fornecedores) AND cat LIKE '1119_%') OR (cat='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO'])))>0
          THEN sum(value) FILTER(WHERE metric='FAT' AND (cat=ANY(p_fornecedores) OR ('1119'=ANY(p_fornecedores) AND cat LIKE '1119_%') OR (cat='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO'])))
          ELSE sum(value) FILTER(WHERE metric='FAT' AND (cat='pepsico_all' OR (no_total AND cat IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')))) END meta_fat_selected,
     sum(value) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods')))) meta_vol_geral,
     sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_elma') meta_vol_elma,
     sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_foods') meta_vol_foods,
     CASE
       WHEN v_has_elma AND v_has_foods THEN count(*) FILTER(WHERE metric='VOL' AND cat IN ('tonelada_elma','tonelada_foods'))
       WHEN v_has_elma THEN count(*) FILTER(WHERE metric='VOL' AND cat='tonelada_elma')
       WHEN v_has_foods THEN count(*) FILTER(WHERE metric='VOL' AND cat='tonelada_foods')
       ELSE count(*) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods'))))
     END saved_vol_selected_count,
     CASE
       WHEN v_has_elma AND v_has_foods THEN COALESCE(sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_elma'),0)+COALESCE(sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_foods'),0)
       WHEN v_has_elma THEN sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_elma')
       WHEN v_has_foods THEN sum(value) FILTER(WHERE metric='VOL' AND cat='tonelada_foods')
       ELSE sum(value) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods'))))
     END meta_vol_selected,
     sum(value) FILTER(WHERE metric='POS') meta_pos_geral,
     sum(value) FILTER(WHERE metric='MIX' AND cat='mix_salty') meta_pos_salty,
     sum(value) FILTER(WHERE metric='MIX' AND cat='mix_foods') meta_pos_foods,
     0::numeric meta_fat_cat,0::numeric meta_vol_cat,0::numeric meta_pos_cat
     FROM targets GROUP BY mes
    ), client_month AS (
     SELECT substring(month_key,1,4)::integer ano,substring(month_key,6,2)::integer mes,codcli,
     sum(vlvenda) FILTER(WHERE tipovenda IN ('1','9')) vlvenda_total,
     sum(totpesoliq) FILTER(WHERE tipovenda NOT IN ('5','11')) peso_total,
     (NULLIF(btrim(codcli),'') IS NOT NULL AND
         coalesce(sum(vlvenda) FILTER (WHERE tipovenda NOT IN ('5','11')),0)>=1)::integer is_positivado,
     max((mix_marca='CHEETOS' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_cheetos,
     max((mix_marca='DORITOS' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_doritos,
     max((mix_marca='FANDANGOS' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_fandangos,
     max((mix_marca='RUFFLES' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_ruffles,
     max((mix_marca='TORCIDA' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_torcida,
     max((mix_marca='TODDYNHO' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_toddynho,
     max((mix_marca='TODDY' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_toddy,
     max((mix_marca='QUAKER' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_quaker,
     max((mix_marca='KEROCOCO' AND vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) has_kerococo
     FROM raw_scoped GROUP BY month_key,codcli
    ), base_realizado_atual AS (SELECT * FROM client_month WHERE ano=p_ano),
    base_realizado_anterior AS (SELECT * FROM client_month WHERE ano=p_ano-1),
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
    
    -- Reserve only open imported targets; closed months contribute their actual sales.
    pesos_restantes_abertos AS (
        SELECT
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE((CASE WHEN v_has_supplier AND ms.saved_fat_supplier_count>0 THEN ms.saved_fat_supplier_count ELSE ms.saved_fat_count END),0)=0 THEN pm.peso_fat ELSE 0 END) AS soma_peso_fat_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE((CASE WHEN v_has_supplier AND ms.saved_fat_supplier_count>0 THEN ms.saved_fat_supplier_count ELSE ms.saved_fat_count END),0)>0 THEN COALESCE((CASE WHEN p_categoria!='Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_selected END),0) ELSE 0 END) AS metas_salvas_fat_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_vol_selected_count,0)=0 THEN pm.peso_vol ELSE 0 END) AS soma_peso_vol_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_vol_selected_count,0)>0 THEN COALESCE((CASE WHEN p_categoria!='Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_selected END),0) ELSE 0 END) AS metas_salvas_vol_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_pos_count,0)=0 THEN pm.peso_pos ELSE 0 END) AS soma_peso_pos_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_pos_count,0)>0 THEN COALESCE((CASE WHEN p_categoria!='Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END),0) ELSE 0 END) AS metas_salvas_pos_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_salty_count,0)=0 THEN pm.peso_salty ELSE 0 END) AS soma_peso_salty_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_salty_count,0)>0 THEN COALESCE(ms.meta_pos_salty,0) ELSE 0 END) AS metas_salvas_salty_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_foods_count,0)=0 THEN pm.peso_foods ELSE 0 END) AS soma_peso_foods_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_foods_count,0)>0 THEN COALESCE(ms.meta_pos_foods,0) ELSE 0 END) AS metas_salvas_foods_restante
        FROM pesos_mes_anterior pm
        LEFT JOIN metas_salvas ms ON ms.mes=pm.mes
    ),

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
                WHEN (CASE WHEN v_has_supplier AND ms.saved_fat_supplier_count>0 THEN ms.saved_fat_supplier_count ELSE ms.saved_fat_count END) > 0 THEN CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_selected END
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_fat_geral, 0)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_selected END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_fat_restante > 0 THEN
                            GREATEST(0, (t.total_fat * (1 + (v_percentual / 100.0)) - r_fechado.fat_realizado_fechado - pr.metas_salvas_fat_restante)) * (pm.peso_fat / pr.soma_peso_fat_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_fat,

            -- Meta Fixa de faturamento: histórico mensal + crescimento, em todos os meses.
            CASE
                WHEN v_percentual IS NULL THEN NULL
                ELSE COALESCE(ra.real_fat_geral, 0) * (1 + (v_percentual / 100.0))
            END as kpi_meta_fixa_fat,

            -- Tonelada (Vol)
            COALESCE(ra.real_vol_geral, 0) as kpi_realizado_anterior_vol,
            COALESCE(r.real_vol_geral, 0) as kpi_realizado_atual_vol,
            
            CASE 
                WHEN ms.saved_vol_selected_count > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_selected END)
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_vol_geral, 0)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_selected END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_vol_restante > 0 THEN
                            GREATEST(0, (t.total_vol * (1 + (v_percentual / 100.0)) - r_fechado.vol_realizado_fechado - pr.metas_salvas_vol_restante)) * (pm.peso_vol / pr.soma_peso_vol_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_vol,

            CASE WHEN v_percentual IS NULL THEN NULL
                ELSE COALESCE(ra.real_vol_geral,0) * (1 + v_percentual/100.0)
            END as kpi_meta_fixa_vol,

            -- Positicação Geral
            COALESCE(ra.real_pos_geral, 0) as kpi_realizado_anterior_pos,
            COALESCE(r.real_pos_geral, 0) as kpi_realizado_atual_pos,
            CASE 
                WHEN NOT v_pos_supported THEN NULL
                WHEN ms.saved_pos_count > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END)
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_geral, 0)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_pos_cat ELSE ms.meta_pos_geral END), 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_pos_restante > 0 THEN
                            GREATEST(t.total_sum_pos_geral*(1+v_percentual/100.0)-r_fechado.pos_geral_realizado_fechado-pr.metas_salvas_pos_restante,0) * (pm.peso_pos / pr.soma_peso_pos_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_pos,

            CASE WHEN NOT v_pos_supported OR v_percentual IS NULL THEN NULL
                ELSE COALESCE(ra.real_pos_geral,0) * (1 + v_percentual/100.0)
            END as kpi_meta_fixa_pos,

            -- Positivação Salty
            COALESCE(ra.real_pos_salty, 0) as kpi_realizado_anterior_salty,
            COALESCE(r.real_pos_salty, 0) as kpi_realizado_atual_salty,
            CASE 
                WHEN ms.saved_salty_count > 0 THEN ms.meta_pos_salty
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_salty, 0)
                WHEN v_percentual IS NULL THEN COALESCE(ms.meta_pos_salty, 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_salty_restante > 0 THEN
                            GREATEST(t.total_sum_pos_salty*(1+v_percentual/100.0)-r_fechado.pos_salty_realizado_fechado-pr.metas_salvas_salty_restante,0) * (pm.peso_salty / pr.soma_peso_salty_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_salty,

            CASE WHEN v_percentual IS NULL THEN NULL ELSE COALESCE(ra.real_pos_salty,0)*(1+v_percentual/100.0) END as kpi_meta_fixa_salty,

            -- Positivação Foods
            COALESCE(ra.real_pos_foods, 0) as kpi_realizado_anterior_foods,
            COALESCE(r.real_pos_foods, 0) as kpi_realizado_atual_foods,
            CASE 
                WHEN ms.saved_foods_count > 0 THEN ms.meta_pos_foods
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_pos_foods, 0)
                WHEN v_percentual IS NULL THEN COALESCE(ms.meta_pos_foods, 0)
                ELSE 
                    CASE 
                        WHEN pr.soma_peso_foods_restante > 0 THEN
                            GREATEST(t.total_sum_pos_foods*(1+v_percentual/100.0)-r_fechado.pos_foods_realizado_fechado-pr.metas_salvas_foods_restante,0) * (pm.peso_foods / pr.soma_peso_foods_restante)
                        ELSE 0 
                    END
            END as kpi_meta_estimada_foods,

            CASE WHEN v_percentual IS NULL THEN NULL ELSE COALESCE(ra.real_pos_foods,0)*(1+v_percentual/100.0) END as kpi_meta_fixa_foods

        FROM meses m
        LEFT JOIN agregado_realizado_atual r ON r.mes = m.mes
        LEFT JOIN agregado_realizado_anterior ra ON ra.mes = m.mes
        LEFT JOIN metas_salvas ms ON ms.mes = m.mes
        LEFT JOIN pesos_mes_anterior pm ON pm.mes = m.mes
        CROSS JOIN totais_anterior t
        CROSS JOIN pesos_restantes_abertos pr
        CROSS JOIN realizado_meses_fechados r_fechado
        CROSS JOIN realizado_anual_unicos r_ano
        ORDER BY m.mes
    )

    SELECT jsonb_build_object(
        'chart_data', COALESCE(jsonb_agg(row_to_json(chart_data)), '[]'::jsonb),
        'target_rows', COALESCE((SELECT jsonb_agg(m) FROM target_rows),'[]'::jsonb),
        'pos_target_supported', v_pos_supported,
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
$function$;

CREATE OR REPLACE FUNCTION public.get_metas_base_comparativo_multi(p_ano integer, p_mes integer, p_filiais text[] DEFAULT '{}'::text[], p_fornecedores text[] DEFAULT '{}'::text[], p_supervisores text[] DEFAULT '{}'::text[], p_vendedores text[] DEFAULT '{}'::text[], p_categorias text[] DEFAULT '{}'::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '55s'
 SET work_mem TO '90MB'
AS $function$
DECLARE b jsonb; t jsonb; scoped_official jsonb; growth numeric;
BEGIN
 PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL)d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 p_fornecedores:=private.evolution_goals_canonical_suppliers(p_fornecedores);
 b:=private.evolution_goals_base(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 t:=private.evolution_goals_targets(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 SELECT percentual INTO growth FROM metas_crescimento WHERE ano=p_ano;
 WITH existing AS (SELECT value s FROM jsonb_array_elements(b->'sellers')),
 owners AS (SELECT DISTINCT m->>'codusur' code,m->>'vendedor_nome' name,m->>'supervisor_codigo' parent FROM jsonb_array_elements(t)m),
 current_parents AS (SELECT code,max(parent) parent FROM owners GROUP BY code),
 all_sellers AS (
  SELECT s FROM existing UNION ALL SELECT jsonb_build_object('codusur',code,'vendedor_nome',name)
  FROM owners o WHERE NOT EXISTS(SELECT 1 FROM existing e WHERE e.s->>'codusur'=o.code)
 ) SELECT jsonb_set(b,'{sellers}',coalesce(jsonb_agg(s || jsonb_build_object(
  'supervisor_codigo',coalesce(p.parent,s->>'supervisor_codigo',''),
  'supervisor_nome',CASE WHEN s->>'codusur'='__PENDENTE__' THEN 'PENDENTES DE ATRIBUIÇÃO'
   ELSE coalesce(d.nome,s->>'supervisor_nome','SEM SUPERVISOR') END) ORDER BY s->>'vendedor_nome'),'[]')) INTO b
 FROM all_sellers a LEFT JOIN current_parents p ON p.code=a.s->>'codusur' LEFT JOIN dim_supervisores d ON d.codigo=p.parent;
 IF cardinality(p_fornecedores)>0 THEN
  scoped_official:=private.evolution_dashboard_targets(p_ano,p_mes,
   jsonb_build_object('p_filial',p_filiais,'p_fornecedor',p_fornecedores,'p_supervisor',p_supervisores,
    'p_vendedor',p_vendedores,'p_categoria',p_categorias));
 END IF;
 RETURN b||jsonb_build_object('effective_filters',jsonb_build_object('filiais',p_filiais,'fornecedores',p_fornecedores,
   'supervisores',p_supervisores,'vendedores',p_vendedores,'categorias',p_categorias),
  'scoped_official',scoped_official,'metas',t,'growth',growth,'scope_version',2,'attribution_version',1,
  'attribution',public.get_meta_attribution_status(p_ano,p_mes));
END $function$;

CREATE OR REPLACE FUNCTION public.get_metas_anuais_chart_multi(p_ano integer, p_mes_atual integer DEFAULT 12, p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '55s'
 SET work_mem TO '90MB'
AS $function$BEGIN PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);
 p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);
 p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL) d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 p_fornecedores:=private.evolution_goals_canonical_suppliers(p_fornecedores);
 RETURN private.evolution_goals_chart(p_ano,p_mes_atual,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias); END;$function$;
