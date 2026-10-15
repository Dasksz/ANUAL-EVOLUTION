-- One filtered union, before aggregation. No changes to sales or imported targets.
BEGIN;
CREATE OR REPLACE FUNCTION private.evolution_goals_values(a text[])
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
 SELECT COALESCE(array_agg(DISTINCT upper(btrim(x)) ORDER BY upper(btrim(x))),ARRAY[]::text[])
 FROM unnest(a) x WHERE NULLIF(btrim(x),'') IS NOT NULL
 AND upper(btrim(x)) NOT IN ('TODOS','TODAS','AMBAS');
$$;
CREATE OR REPLACE FUNCTION private.evolution_goals_match(v text, label text, a text[])
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
 SELECT coalesce(cardinality(a),0)=0 OR upper(btrim(coalesce(v,'')))=ANY(a)
 OR upper(btrim(coalesce(label,'')))=ANY(a);
$$;
CREATE OR REPLACE FUNCTION private.evolution_goals_sales(
 p_from date,p_to date,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
RETURNS TABLE(codusur text,codsupervisor text,month_key text,codfor text,categoria_produto text,
 mix_marca text,vlvenda numeric,totpesoliq numeric,codcli text,tipovenda text,filial text)
LANGUAGE sql STABLE AS $$
 WITH raw AS (
 SELECT d.codusur,d.codsupervisor,d.dtped,d.codfor,d.produto,d.vlvenda,d.totpesoliq,d.codcli,d.tipovenda,d.filial
 FROM public.data_detailed_current d WHERE d.dtped>=p_from AND d.dtped<p_to
 UNION ALL
 SELECT d.codusur,d.codsupervisor,d.dtped,d.codfor,d.produto,d.vlvenda,d.totpesoliq,d.codcli,d.tipovenda,d.filial
 FROM public.data_history_current d WHERE d.dtped>=p_from AND d.dtped<p_to
 ), f AS MATERIALIZED (SELECT private.evolution_goals_values(p_filiais) fi,
 private.evolution_goals_values(p_fornecedores) fo,private.evolution_goals_values(p_supervisores) su,
 private.evolution_goals_values(p_vendedores) ve,private.evolution_goals_values(p_categorias) ca)
 SELECT d.codusur::text,d.codsupervisor::text,to_char(d.dtped,'YYYY-MM'),ltrim(d.codfor::text,'0'),
 upper(dp.categoria_produto),upper(dp.mix_marca),d.vlvenda::numeric,d.totpesoliq::numeric,
 d.codcli::text,d.tipovenda::text,d.filial::text
 FROM raw d LEFT JOIN public.dim_produtos dp ON dp.codigo=d.produto
 LEFT JOIN public.dim_vendedores dv ON dv.codigo=d.codusur
 LEFT JOIN public.dim_supervisores ds ON ds.codigo=d.codsupervisor CROSS JOIN f
 WHERE (cardinality(f.fi)=0 OR upper(d.filial::text)=ANY(f.fi))
 AND (cardinality(f.ve)=0 OR upper(d.codusur::text)=ANY(f.ve) OR upper(trim(dv.nome))=ANY(f.ve))
 AND (cardinality(f.su)=0 OR upper(d.codsupervisor::text)=ANY(f.su) OR upper(trim(ds.nome))=ANY(f.su))
 AND (cardinality(f.ca)=0 OR upper(dp.categoria_produto)=ANY(f.ca) OR upper(dp.mix_marca)=ANY(f.ca))
 AND (cardinality(f.fo)=0 OR ltrim(d.codfor::text,'0')=ANY(f.fo)
 OR (ltrim(d.codfor::text,'0')='1119' AND EXISTS(SELECT 1 FROM unnest(f.fo) selected WHERE
 selected='1119' OR (selected='1119_QUAKER_KEROCOCO' AND (upper(dp.mix_marca) IN ('QUAKER','KEROCOCO') OR upper(dp.categoria_produto) LIKE '%QUAKER%' OR upper(dp.categoria_produto) LIKE '%KEROCOCO%'))
 OR (selected='1119_TODDYNHO' AND (upper(dp.mix_marca)='TODDYNHO' OR upper(dp.categoria_produto) LIKE '%TODDYNHO%' OR upper(dp.categoria_produto) LIKE '%TODYNHO%'))
 OR (selected='1119_TODDY' AND (upper(dp.mix_marca)='TODDY' OR upper(dp.categoria_produto)='TODDY' OR upper(dp.categoria_produto) LIKE '%TODDY %'))
 OR (selected='1119_QUAKER' AND (upper(dp.mix_marca)='QUAKER' OR upper(dp.categoria_produto) LIKE '%QUAKER%'))
 OR (selected='1119_KEROCOCO' AND (upper(dp.mix_marca)='KEROCOCO' OR upper(dp.categoria_produto) LIKE '%KEROCOCO%')))));
$$;
CREATE OR REPLACE FUNCTION private.evolution_goals_base(p_ano integer,p_mes integer,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_temp AS $function$
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
        SELECT CASE codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE codusur END AS codusur, codsupervisor, COUNT(*) AS sale_count
        FROM public.data_summary_current
        GROUP BY CASE codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE codusur END, codsupervisor
    ), supervisor_by_seller AS (
        SELECT DISTINCT ON (codusur) codusur, codsupervisor
        FROM supervisor_counts
        ORDER BY codusur, sale_count DESC, codsupervisor
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
CREATE OR REPLACE FUNCTION private.evolution_goals_target_field(cat text,metric text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE metric
 WHEN 'FAT' THEN 'total_fat_' WHEN 'VOL' THEN 'total_vol_' WHEN 'POS' THEN 'sum_pos_' WHEN 'MIX' THEN 'sum_mix_' ELSE '' END ||
 CASE cat WHEN 'pepsico_all' THEN 'geral' WHEN 'total_elma' THEN 'elma' WHEN 'tonelada_elma' THEN 'elma'
 WHEN 'total_foods' THEN 'foods' WHEN 'tonelada_foods' THEN 'foods' WHEN 'mix_salty' THEN 'salty'
 WHEN 'mix_foods' THEN 'foods' WHEN '1119_TODDYNHO' THEN 'toddynho' WHEN '1119_TODDY' THEN 'toddy'
 WHEN '1119_QUAKER_KEROCOCO' THEN 'quaker_kerococo' WHEN 'pedev' THEN 'elma' ELSE cat END;
$$;
CREATE OR REPLACE FUNCTION private.evolution_goals_targets(p_ano integer,p_mes integer,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_temp AS $$
DECLARE full_base jsonb; scoped_base jsonb; result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 full_base:=private.evolution_goals_base(p_ano,p_mes);
 scoped_base:=private.evolution_goals_base(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 WITH all_sellers AS (SELECT value s FROM jsonb_array_elements(full_base->'sellers')),
 selected AS (SELECT value s FROM jsonb_array_elements(scoped_base->'sellers')),
 metas AS (
 SELECT DISTINCT ON (dv.codigo,m.categoria,m.metrica) m.*,dv.codigo code,dv.nome seller_name,
 private.evolution_goals_target_field(m.categoria,m.metrica) field
 FROM public.farol_metas_current m JOIN public.dim_vendedores dv ON
 ((m.codusur IS NOT NULL AND dv.codigo=m.codusur) OR (m.codusur IS NULL AND upper(trim(dv.nome))=upper(trim(m.vendedor_nome))))
 WHERE m.ano=p_ano AND m.mes=p_mes AND upper(dv.nome) NOT LIKE 'INATIVOS%'
 ORDER BY dv.codigo,m.categoria,m.metrica,m.updated_at DESC,m.id
 ), weights AS (
 SELECT m.*,a.s all_s,s.s scoped_s,
 CASE WHEN coalesce((a.s->>m.field)::numeric,0)>0 THEN
 least(1,greatest(0,coalesce((s.s->>m.field)::numeric,0)/(a.s->>m.field)::numeric))
 WHEN coalesce(cardinality(private.evolution_goals_values(p_filiais)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_supervisores)),0)=0
 AND private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores)) THEN 1
 WHEN a.s IS NULL AND 'SEM SUPERVISOR'=ANY(private.evolution_goals_values(p_supervisores)) AND coalesce(cardinality(p_filiais),0)=0 AND coalesce(cardinality(p_fornecedores),0)=0 AND coalesce(cardinality(p_categorias),0)=0 THEN 1
 WHEN s.s IS NOT NULL AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0 THEN 1 ELSE 0 END factor
 FROM metas m LEFT JOIN all_sellers a ON a.s->>'codusur'=m.code
 LEFT JOIN selected s ON s.s->>'codusur'=m.code
 WHERE private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores))
 ), allowed AS (
 SELECT w.* FROM weights w WHERE factor>0 AND
 (coalesce(cardinality(p_fornecedores),0)=0 OR
 (w.categoria IN ('pepsico_all','pedev','mix_salty','mix_foods','total_elma','total_foods','tonelada_elma','tonelada_foods')) OR
 w.categoria=ANY(p_fornecedores) OR ('1119'=ANY(p_fornecedores) AND w.categoria LIKE '1119_%') OR
 (w.categoria='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO']))
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'ano',ano,'mes',mes,'codusur',code,'vendedor_nome',seller_name,
 'categoria',categoria,'metrica',metrica,'valor_ajuste',CASE WHEN metrica IN ('POS','MIX') THEN round(valor_ajuste*factor) ELSE valor_ajuste*factor END,
 'source_value',valor_ajuste,'scope_factor',factor)), '[]'::jsonb) INTO result FROM allowed;
 RETURN result;
END;$$;
CREATE OR REPLACE FUNCTION private.evolution_goals_chart(p_ano integer,p_mes_atual integer DEFAULT 12,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_temp AS $function$
DECLARE
    v_result JSONB;
    p_categoria text := 'Todos';
    p_fornecedor text := 'Todos';
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
     SELECT e.value m FROM (SELECT DISTINCT mes FROM public.farol_metas_current WHERE ano=p_ano) months
     CROSS JOIN LATERAL jsonb_array_elements(private.evolution_goals_targets(p_ano,months.mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias)) e
    ), targets AS (
     SELECT m, (m->>'mes')::integer mes,(m->>'metrica') metric,m->>'categoria' cat,(m->>'valor_ajuste')::numeric value,
     NOT EXISTS (SELECT 1 FROM target_rows t WHERE t.m->>'codusur'=r.m->>'codusur' AND t.m->>'mes'=r.m->>'mes'
      AND t.m->>'metrica'=r.m->>'metrica' AND t.m->>'categoria'='pepsico_all' AND (t.m->>'valor_ajuste') IS NOT NULL) no_total
     FROM target_rows r WHERE (m->>'valor_ajuste') IS NOT NULL
    ), metas_salvas AS (
     SELECT mes,
     count(*) FILTER(WHERE metric='FAT' AND (cat='pepsico_all' OR (no_total AND cat IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')))) saved_fat_count,
     count(*) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods')))) saved_vol_count,
     count(*) FILTER(WHERE metric='POS' AND cat='pepsico_all') saved_pos_count,
     count(*) FILTER(WHERE metric='MIX' AND cat='mix_salty') saved_salty_count,
     count(*) FILTER(WHERE metric='MIX' AND cat='mix_foods') saved_foods_count,
     sum(value) FILTER(WHERE metric='FAT' AND (cat='pepsico_all' OR (no_total AND cat IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')))) meta_fat_geral,
     sum(value) FILTER(WHERE metric='VOL' AND (cat='pepsico_all' OR (no_total AND cat IN ('tonelada_elma','tonelada_foods')))) meta_vol_geral,
     sum(value) FILTER(WHERE metric='POS' AND cat='pepsico_all') meta_pos_geral,
     sum(value) FILTER(WHERE metric='MIX' AND cat='mix_salty') meta_pos_salty,
     sum(value) FILTER(WHERE metric='MIX' AND cat='mix_foods') meta_pos_foods,
     0::numeric meta_fat_cat,0::numeric meta_vol_cat,0::numeric meta_pos_cat
     FROM targets GROUP BY mes
    ), client_month AS (
     SELECT substring(month_key,1,4)::integer ano,substring(month_key,6,2)::integer mes,codcli,
     sum(vlvenda) FILTER(WHERE tipovenda IN ('1','9')) vlvenda_total,
     sum(totpesoliq) FILTER(WHERE tipovenda NOT IN ('5','11')) peso_total,
     max((vlvenda>0 AND tipovenda NOT IN ('5','11'))::integer) is_positivado,
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
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_fat_count,0)=0 THEN pm.peso_fat ELSE 0 END) AS soma_peso_fat_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_fat_count,0)>0 THEN COALESCE((CASE WHEN p_categoria!='Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END),0) ELSE 0 END) AS metas_salvas_fat_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_vol_count,0)=0 THEN pm.peso_vol ELSE 0 END) AS soma_peso_vol_restante,
            SUM(CASE WHEN pm.mes>v_mes_fechado AND COALESCE(ms.saved_vol_count,0)>0 THEN COALESCE((CASE WHEN p_categoria!='Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END),0) ELSE 0 END) AS metas_salvas_vol_restante,
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
                WHEN ms.saved_fat_count > 0 THEN CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_fat_geral, 0)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_fat_cat ELSE ms.meta_fat_geral END), 0)
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
                WHEN ms.saved_vol_count > 0 THEN (CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END)
                WHEN m.mes <= v_mes_fechado THEN COALESCE(r.real_vol_geral, 0)
                WHEN v_percentual IS NULL THEN COALESCE((CASE WHEN p_categoria != 'Todos' THEN ms.meta_vol_cat ELSE ms.meta_vol_geral END), 0)
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

            CASE WHEN v_percentual IS NULL THEN NULL
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
CREATE OR REPLACE FUNCTION public.get_metas_base_comparativo_multi(p_ano integer,p_mes integer,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$DECLARE b jsonb;t jsonb; growth numeric;BEGIN
 PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);
 p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);
 p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL) d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 IF p_fornecedores @> ARRAY['707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'] THEN p_fornecedores:='{}'; END IF;

 b:=private.evolution_goals_base(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 t:=private.evolution_goals_targets(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 SELECT percentual INTO growth FROM public.metas_crescimento WHERE ano=p_ano;
 -- Include valid imported-target owners even without sales in the trailing quarter.
 WITH existing AS (SELECT value s FROM jsonb_array_elements(b->'sellers')),
 owners AS (SELECT DISTINCT m->>'codusur' code,m->>'vendedor_nome' name FROM jsonb_array_elements(t) m)
 SELECT jsonb_set(b,'{sellers}',coalesce((SELECT jsonb_agg(s ORDER BY s->>'vendedor_nome') FROM (
 SELECT s FROM existing UNION ALL
 SELECT jsonb_build_object('codusur',code,'vendedor_nome',name,'supervisor_nome','SEM SUPERVISOR','supervisor_codigo','') FROM owners o
 WHERE NOT EXISTS(SELECT 1 FROM existing e WHERE e.s->>'codusur'=o.code)) q),'[]'::jsonb)) INTO b;
 RETURN b||jsonb_build_object('metas',t,'growth',growth,'scope_version',2);
END;$$;
CREATE OR REPLACE FUNCTION public.get_metas_anuais_chart_multi(p_ano integer,p_mes_atual integer DEFAULT 12,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$BEGIN PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);
 p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);
 p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL) d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 IF p_fornecedores @> ARRAY['707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'] THEN p_fornecedores:='{}'; END IF;
 RETURN private.evolution_goals_chart(p_ano,p_mes_atual,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias); END;$$;
CREATE OR REPLACE FUNCTION public.get_metas_people_multi(p_ano integer,p_mes integer,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$BEGIN PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);
 p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);
 p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL) d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 IF p_fornecedores @> ARRAY['707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'] THEN p_fornecedores:='{}'; END IF;
 RETURN public.get_metas_base_comparativo_multi(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias); END;$$;
REVOKE ALL ON FUNCTION private.evolution_goals_values(text[]) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_match(text,text,text[]) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_sales(date,date,text[],text[],text[],text[],text[]) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_base(integer,integer,text[],text[],text[],text[],text[]) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_targets(integer,integer,text[],text[],text[],text[],text[]) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_target_field(text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.evolution_goals_chart(integer,integer,text[],text[],text[],text[],text[]) FROM PUBLIC,anon,authenticated;
COMMIT;
