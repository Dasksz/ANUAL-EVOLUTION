-- Reuse imported targets directly when no filters are selected.
-- With an empty filter set, each imported target's scope factor is exactly 1.
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
BEGIN
    PERFORM private.evolution_assert_approved();
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
        'target_rows', COALESCE((SELECT jsonb_agg(m) FROM target_rows),'[]'::jsonb),
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

CREATE OR REPLACE FUNCTION private.evolution_goals_targets(
 p_ano integer,p_mes integer,p_filiais text[] DEFAULT '{}',p_fornecedores text[] DEFAULT '{}',
 p_supervisores text[] DEFAULT '{}',p_vendedores text[] DEFAULT '{}',p_categorias text[] DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 SELECT coalesce(jsonb_agg(jsonb_build_object('ano',p_ano,'mes',p_mes,'codusur',private.evolution_seller_code(e->>'codigo'),
  'categoria',e->>'categoria','metrica',e->>'metrica','valor_ajuste',e->'valor','source_value',e->'meta_original',
  'scope_factor',CASE WHEN (e->>'meta_original')::numeric>0 THEN (e->>'valor')::numeric/(e->>'meta_original')::numeric ELSE 1 END,
  'vendedor_nome',(SELECT t.nome FROM private.evolution_official_targets t WHERE t.ano=p_ano AND t.mes=p_mes AND t.nivel='vendedor' AND t.codigo_entidade=e->>'codigo' LIMIT 1))), '[]') INTO result
 FROM jsonb_array_elements(private.evolution_dashboard_targets(p_ano,p_mes,
  jsonb_build_object('force_level','vendedor','all_metrics',true,'p_filial',p_filiais,'p_fornecedor',p_fornecedores,
  'p_supervisor',p_supervisores,'p_vendedor',p_vendedores,'p_categoria',p_categorias))) e;
 RETURN result;
END $$;

-- Imported month owns its hierarchy, including the temporary vacation portfolios.
DO $patch$ DECLARE definition text; BEGIN
 SELECT pg_get_functiondef('public.get_metas_base_comparativo_multi(integer,integer,text[],text[],text[],text[],text[])'::regprocedure) INTO definition;
 IF position('Imported hierarchy overrides' IN definition)=0 THEN
 definition:=replace(definition, ' RETURN b||', $replacement$
 -- Imported hierarchy overrides current roster only for this imported period.
 SELECT jsonb_set(b,'{sellers}',coalesce(jsonb_agg(e || CASE WHEN parent.codigo_entidade IS NOT NULL THEN
  jsonb_build_object('supervisor_codigo',parent.codigo_entidade,'supervisor_nome',parent.nome) ELSE '{}'::jsonb END),'[]')) INTO b
 FROM jsonb_array_elements(b->'sellers') e
 LEFT JOIN (SELECT DISTINCT codigo_entidade,supervisor_codigo FROM private.metas_planilha WHERE ano=p_ano AND mes=p_mes AND nivel='vendedor') leaf
  ON private.evolution_seller_code(leaf.codigo_entidade)=e->>'codusur'
 LEFT JOIN (SELECT DISTINCT codigo_entidade,nome FROM private.metas_planilha WHERE ano=p_ano AND mes=p_mes AND nivel='supervisor') parent
  ON parent.codigo_entidade=leaf.supervisor_codigo;
 RETURN b||$replacement$);
 EXECUTE definition;
 END IF;
END $patch$;
