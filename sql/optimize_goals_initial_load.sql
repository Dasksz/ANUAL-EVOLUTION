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

    metas_salvas AS (
        SELECT
            m.mes,
            COUNT(*) FILTER (WHERE m.metrica='FAT' AND (CASE WHEN p_categoria != 'Todos' THEN UPPER(m.categoria)=UPPER(p_categoria) ELSE
 ((p_fornecedor='Todos' AND m.categoria IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO','pepsico_all')) OR
 (p_fornecedor!='Todos' AND (m.categoria=p_fornecedor OR
 (p_fornecedor IN ('1119_QUAKER','1119_KEROCOCO','1119_QUAKER_KEROCOCO','QUAKER','KEROCOCO') AND m.categoria='1119_QUAKER_KEROCOCO') OR
 (p_fornecedor='1119' AND m.categoria LIKE '1119_%')))) END)) AS saved_fat_count,
            COUNT(*) FILTER (WHERE m.metrica='VOL' AND (CASE WHEN p_categoria != 'Todos' THEN UPPER(m.categoria)=UPPER(p_categoria) ELSE
 ((p_fornecedor='Todos' AND m.categoria IN ('tonelada_elma','tonelada_foods','pepsico_all')) OR
 (p_fornecedor!='Todos' AND (m.categoria=p_fornecedor OR
 (p_fornecedor IN ('1119_QUAKER','1119_KEROCOCO','1119_QUAKER_KEROCOCO','QUAKER','KEROCOCO') AND m.categoria='1119_QUAKER_KEROCOCO') OR
 (p_fornecedor='1119' AND m.categoria LIKE '1119_%')))) END)) AS saved_vol_count,
            COUNT(*) FILTER (WHERE m.metrica='POS' AND (CASE WHEN p_categoria != 'Todos' THEN UPPER(m.categoria)=UPPER(p_categoria) ELSE
 ((p_fornecedor='Todos' AND m.categoria IN ('pepsico_all')) OR
 (p_fornecedor!='Todos' AND (m.categoria=p_fornecedor OR
 (p_fornecedor IN ('1119_QUAKER','1119_KEROCOCO','1119_QUAKER_KEROCOCO','QUAKER','KEROCOCO') AND m.categoria='1119_QUAKER_KEROCOCO') OR
 (p_fornecedor='1119' AND m.categoria LIKE '1119_%')))) END)) AS saved_pos_count,
            COUNT(*) FILTER (WHERE m.metrica='MIX' AND m.categoria='mix_salty') AS saved_salty_count,
            COUNT(*) FILTER (WHERE m.metrica='MIX' AND m.categoria='mix_foods') AS saved_foods_count,
            SUM(CASE WHEN m.metrica = 'FAT' AND (
                (p_fornecedor = 'Todos' AND (m.categoria='pepsico_all' OR (
                m.categoria IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')
                AND NOT EXISTS (SELECT 1 FROM public.metas_sv mg WHERE mg.ano=m.ano AND mg.mes=m.mes
                  AND mg.vendedor_nome=m.vendedor_nome AND mg.categoria='pepsico_all' AND mg.metrica='FAT')))) OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', '1119_QUAKER_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_fat_geral,
            SUM(CASE WHEN m.metrica = 'VOL' AND (
                (p_fornecedor = 'Todos' AND (m.categoria='pepsico_all' OR (
                m.categoria IN ('tonelada_elma','tonelada_foods')
                AND NOT EXISTS (SELECT 1 FROM public.metas_sv mg WHERE mg.ano=m.ano AND mg.mes=m.mes
                  AND mg.vendedor_nome=m.vendedor_nome AND mg.categoria='pepsico_all' AND mg.metrica='VOL')))) OR
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
CREATE OR REPLACE FUNCTION public.get_metas_people_filtered(p_ano integer, p_mes integer, p_filial text DEFAULT 'Todas'::text, p_fornecedor text DEFAULT 'Todos'::text, p_codsupervisor text DEFAULT NULL::text, p_codusur text DEFAULT NULL::text, p_categoria text DEFAULT 'Todos'::text)
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
    p_codusur := CASE p_codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE p_codusur END;
    WITH supervisor_counts AS MATERIALIZED (
        SELECT CASE codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE codusur END AS codusur, codsupervisor, COUNT(*) AS sale_count
        FROM public.data_summary
        GROUP BY CASE codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE codusur END, codsupervisor
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
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
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
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
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
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
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
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
            END)::text = p_codusur
              OR (CASE
                WHEN d.codusur LIKE 'INAT_%'
                     AND c.rca1 IS NOT NULL AND c.rca1 <> ''
                     AND EXISTS (
                         SELECT 1 FROM public.dim_vendedores dv_eff
                         WHERE dv_eff.codigo = c.rca1
                           AND UPPER(COALESCE(dv_eff.nome,'')) NOT LIKE 'INATIVOS%'
                     )
                THEN CASE c.rca1 WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE c.rca1 END
                ELSE CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
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
    seller_codes AS (
        SELECT DISTINCT codusur FROM raw_sales_all
    ), people AS (
        SELECT s.codusur, dv.nome AS vendedor_nome,
            CASE
                WHEN sup.codsupervisor IN ('18','21') THEN 'RÔMULO AMADO DA'
                WHEN sup.codsupervisor = '12' THEN 'TIAGO JOSÉ DE S'
                WHEN sup.codsupervisor = 'SV_AMERICANAS' THEN 'SV AMERICANAS'
                WHEN sup.codsupervisor = '8' THEN 'BALCAO'
                ELSE ds.nome
            END AS supervisor_nome,
            ds.codigo AS supervisor_codigo
        FROM seller_codes s
        JOIN public.dim_vendedores dv ON dv.codigo=s.codusur
        LEFT JOIN supervisor_by_seller sup ON sup.codusur=s.codusur
        LEFT JOIN public.dim_supervisores ds ON ds.codigo=sup.codsupervisor
        WHERE dv.nome IS NOT NULL AND UPPER(dv.nome) NOT LIKE 'INATIVOS%'
    )
    SELECT jsonb_build_object('sellers',COALESCE(jsonb_agg(to_jsonb(people) ORDER BY vendedor_nome),'[]'::jsonb))
    INTO v_result FROM people;
    RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_metas_people_filtered(integer,integer,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_metas_people_filtered(integer,integer,text,text,text,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.get_metas_people_multi(p_ano integer, p_mes integer, p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_filiais text[] := CASE WHEN COALESCE(cardinality(p_filiais),0)=0 THEN ARRAY['Todas'] ELSE p_filiais END;
    v_fornecedores text[] := CASE WHEN COALESCE(cardinality(p_fornecedores),0)=0 THEN ARRAY['Todos'] ELSE p_fornecedores END;
    v_categorias text[] := CASE WHEN COALESCE(cardinality(p_categorias),0)=0 THEN ARRAY['Todos'] ELSE p_categorias END;
    v_principals text[];
    v_use_vendedores boolean := COALESCE(cardinality(p_vendedores),0)>0;
    v_filial text; v_fornecedor text; v_categoria text; v_principal text;
    v_res jsonb; v_seller jsonb; v_code text;
    v_sellers_map jsonb := '{}'::jsonb;
    v_quarter jsonb := '[]'::jsonb;
BEGIN
    PERFORM private.evolution_assert_approved();

    v_principals := CASE
        WHEN v_use_vendedores THEN p_vendedores
        WHEN COALESCE(cardinality(p_supervisores),0)>0 THEN p_supervisores
        ELSE ARRAY[NULL::text]
    END;

    FOREACH v_filial IN ARRAY v_filiais LOOP
      FOREACH v_fornecedor IN ARRAY v_fornecedores LOOP
        FOREACH v_categoria IN ARRAY v_categorias LOOP
          FOREACH v_principal IN ARRAY v_principals LOOP
            v_res := public.get_metas_people_filtered(
                p_ano, p_mes, v_filial, v_fornecedor,
                CASE WHEN v_use_vendedores THEN NULL ELSE v_principal END,
                CASE WHEN v_use_vendedores THEN v_principal ELSE NULL END,
                v_categoria
            );
            IF v_quarter = '[]'::jsonb THEN v_quarter := COALESCE(v_res->'quarterMonths','[]'::jsonb); END IF;
            FOR v_seller IN SELECT value FROM jsonb_array_elements(COALESCE(v_res->'sellers','[]'::jsonb))
            LOOP
                v_code := COALESCE(v_seller->>'codusur', v_seller->>'vendedor_nome');
                IF v_code IS NULL THEN CONTINUE; END IF;
                IF v_sellers_map ? v_code THEN
                    v_sellers_map := jsonb_set(v_sellers_map, ARRAY[v_code],
                        private.evolution_sum_jsonb_objects(v_sellers_map->v_code, v_seller), true);
                ELSE
                    v_sellers_map := jsonb_set(v_sellers_map, ARRAY[v_code], v_seller, true);
                END IF;
            END LOOP;
          END LOOP;
        END LOOP;
      END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'quarterMonths', v_quarter,
        'sellers', COALESCE((SELECT jsonb_agg(value ORDER BY value->>'vendedor_nome') FROM jsonb_each(v_sellers_map)), '[]'::jsonb)
    );
END;
$function$
;
REVOKE ALL ON FUNCTION public.get_metas_people_multi(integer,integer,text[],text[],text[],text[],text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_metas_people_multi(integer,integer,text[],text[],text[],text[],text[]) TO authenticated,service_role;


