CREATE OR REPLACE FUNCTION public.get_closing_presentation_data(p_ano text DEFAULT NULL::text, p_mes text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_result JSON;
    v_target_year int;
    v_target_month int;
    v_target_date date;
    
    v_prev_q1_year int; v_prev_q1_month int;
    v_prev_q2_year int; v_prev_q2_month int;
    v_prev_q3_year int; v_prev_q3_month int;
    
    v_prev_year_year int; v_prev_year_month int;
BEGIN
    PERFORM private.evolution_assert_approved();
    -- Determine target period if not provided
    IF p_ano IS NULL OR p_mes IS NULL THEN
        SELECT ano, mes INTO v_target_year, v_target_month
        FROM public.data_summary
        ORDER BY ano DESC, mes DESC
        LIMIT 1;
    ELSE
        v_target_year := p_ano::int;
        v_target_month := p_mes::int;
    END IF;

    -- If still null, return empty
    IF v_target_year IS NULL THEN
        RETURN '{}'::json;
    END IF;
    
    v_target_date := make_date(v_target_year, v_target_month, 1);
    
    -- Calculate previous 3 months for quarterly average
    v_prev_q1_year := EXTRACT(YEAR FROM v_target_date - INTERVAL '1 month')::int;
    v_prev_q1_month := EXTRACT(MONTH FROM v_target_date - INTERVAL '1 month')::int;
    
    v_prev_q2_year := EXTRACT(YEAR FROM v_target_date - INTERVAL '2 months')::int;
    v_prev_q2_month := EXTRACT(MONTH FROM v_target_date - INTERVAL '2 months')::int;
    
    v_prev_q3_year := EXTRACT(YEAR FROM v_target_date - INTERVAL '3 months')::int;
    v_prev_q3_month := EXTRACT(MONTH FROM v_target_date - INTERVAL '3 months')::int;

    -- Calculate previous year (-12 months)
    v_prev_year_year := v_target_year - 1;
    v_prev_year_month := v_target_month;

    -- We use dynamic SQL for extremely fast execution plan caching via CTEs
    EXECUTE $dyn$
    WITH base_data AS MATERIALIZED (
        SELECT
            ds.codcli,
            ds.filial,
            ds.codusur,
            ds.codsupervisor,
            ds.ano,
            ds.mes,
            ds.vlvenda,
            ds.peso,
            ds.tipovenda,
            ds.codfor
        , ds.categoria_produto,
            ds.devolucao,
            ds.bonificacao
        FROM public.data_summary ds
        WHERE (ds.ano, ds.mes) IN ( ($1, $2), ($3, $4), ($5, $6), ($7, $8), ($9, $10) )
    ),
    classified_data AS MATERIALIZED (
        SELECT
            b.codcli,
            b.filial,
            b.codusur,
            b.codsupervisor,
            b.ano,
            b.mes,
            b.vlvenda,
            b.peso,
            b.tipovenda,
            b.devolucao,
            CASE WHEN b.tipovenda = '11' THEN b.bonificacao ELSE 0 END as bonificacao,
            CASE WHEN b.tipovenda = '5' THEN b.bonificacao ELSE 0 END as perdas,
            CASE 
                WHEN LTRIM(b.codfor::text, '0') IN ('707', '708', '752') THEN 'Salty'
                WHEN LTRIM(b.codfor::text, '0') IN ('1119') THEN 'Foods'
                ELSE 'Foods'
            END as line_group
        FROM base_data b
    ),

    grouped_pos AS MATERIALIZED (
        SELECT
            codusur,
            codcli,
            ano,
            mes,
            SUM(vlvenda) as sum_vlvenda,
            SUM(CASE WHEN line_group = 'Salty' THEN vlvenda ELSE 0 END) as sum_vlvenda_salty,
            SUM(CASE WHEN line_group = 'Foods' THEN vlvenda ELSE 0 END) as sum_vlvenda_foods
        FROM classified_data
        GROUP BY codusur, codcli, ano, mes
    ),

    -- AGGREGATES GLOBALS
    agg_global AS (
        SELECT
            'Geral' as group_name,
            'Global' as dimension,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10)) AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN ano = $1 AND mes = $2 AND vlvenda >= 1 THEN codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN ano = $5 AND mes = $6 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $7 AND mes = $8 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $9 AND mes = $10 AND vlvenda >= 1 THEN codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN ano = $3 AND mes = $4 AND vlvenda >= 1 THEN codcli END) as pos_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN devolucao ELSE 0 END) as dev_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN bonificacao ELSE 0 END) as bonificacao_atual,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN devolucao ELSE 0 END) as dev_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN devolucao ELSE 0 END) / 3.0 as dev_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN bonificacao ELSE 0 END) as bonificacao_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN bonificacao ELSE 0 END) / 3.0 as bonificacao_trim,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN perdas ELSE 0 END) as perdas_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN perdas ELSE 0 END) / 3.0 as perdas_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN perdas ELSE 0 END) as perdas_ant
        FROM classified_data
        UNION ALL
        SELECT
            line_group as group_name,
            'Global' as dimension,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10)) AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN ano = $1 AND mes = $2 AND vlvenda >= 1 THEN codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN ano = $5 AND mes = $6 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $7 AND mes = $8 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $9 AND mes = $10 AND vlvenda >= 1 THEN codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN ano = $3 AND mes = $4 AND vlvenda >= 1 THEN codcli END) as pos_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN devolucao ELSE 0 END) as dev_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN bonificacao ELSE 0 END) as bonificacao_atual,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN devolucao ELSE 0 END) as dev_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN devolucao ELSE 0 END) / 3.0 as dev_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN bonificacao ELSE 0 END) as bonificacao_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN bonificacao ELSE 0 END) / 3.0 as bonificacao_trim,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN perdas ELSE 0 END) as perdas_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN perdas ELSE 0 END) / 3.0 as perdas_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN perdas ELSE 0 END) as perdas_ant
        FROM classified_data
        GROUP BY line_group
    ),

    -- AGGREGATES PER FILIAL
    agg_filial AS (
        SELECT
            'Geral' as group_name,
            filial as dimension,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10)) AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN ano = $1 AND mes = $2 AND vlvenda >= 1 THEN codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN ano = $5 AND mes = $6 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $7 AND mes = $8 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $9 AND mes = $10 AND vlvenda >= 1 THEN codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN ano = $3 AND mes = $4 AND vlvenda >= 1 THEN codcli END) as pos_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN devolucao ELSE 0 END) as dev_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN bonificacao ELSE 0 END) as bonificacao_atual,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN devolucao ELSE 0 END) as dev_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN devolucao ELSE 0 END) / 3.0 as dev_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN bonificacao ELSE 0 END) as bonificacao_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN bonificacao ELSE 0 END) / 3.0 as bonificacao_trim,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN perdas ELSE 0 END) as perdas_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN perdas ELSE 0 END) / 3.0 as perdas_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN perdas ELSE 0 END) as perdas_ant
        FROM classified_data
        GROUP BY filial
        UNION ALL
        SELECT
            line_group as group_name,
            filial as dimension,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10)) AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 AND tipovenda NOT IN ('5', '11')
           THEN peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN ano = $1 AND mes = $2 AND vlvenda >= 1 THEN codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN ano = $5 AND mes = $6 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $7 AND mes = $8 AND vlvenda >= 1 THEN codcli END) + COUNT(DISTINCT CASE WHEN ano = $9 AND mes = $10 AND vlvenda >= 1 THEN codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN ano = $3 AND mes = $4 AND vlvenda >= 1 THEN codcli END) as pos_ant,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN devolucao ELSE 0 END) as dev_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN bonificacao ELSE 0 END) as bonificacao_atual,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN devolucao ELSE 0 END) as dev_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN devolucao ELSE 0 END) / 3.0 as dev_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN bonificacao ELSE 0 END) as bonificacao_ant,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN bonificacao ELSE 0 END) / 3.0 as bonificacao_trim,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN perdas ELSE 0 END) as perdas_atual,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN perdas ELSE 0 END) / 3.0 as perdas_trim,
            SUM(CASE WHEN ano = $3 AND mes = $4 THEN perdas ELSE 0 END) as perdas_ant
        FROM classified_data
        GROUP BY filial, line_group
    ),

    -- AGGREGATES PER SUPERVISOR
    agg_supervisor AS (
        SELECT
            'Geral' as group_name,
            c.filial || ' - ' || COALESCE(
                CASE 
                    WHEN MAX(ds.nome) ILIKE 'SV %' OR MAX(ds.nome) ILIKE 'SV_%' 
                    THEN SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 1) || ' ' || SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 2)
                    ELSE SPLIT_PART(MAX(ds.nome), ' ', 1) 
                END, 
                c.codsupervisor
            ) as dimension,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10) THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN c.ano = $1 AND c.mes = $2 AND c.vlvenda >= 1 THEN c.codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN c.ano = $5 AND c.mes = $6 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $7 AND c.mes = $8 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $9 AND c.mes = $10 AND c.vlvenda >= 1 THEN c.codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN c.ano = $3 AND c.mes = $4 AND c.vlvenda >= 1 THEN c.codcli END) as pos_ant
        FROM classified_data c
        LEFT JOIN dim_supervisores ds ON c.codsupervisor = ds.codigo
        GROUP BY c.filial, c.codsupervisor
        HAVING SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) > 0
        UNION ALL
        SELECT
            c.line_group as group_name,
            c.filial || ' - ' || COALESCE(
                CASE 
                    WHEN MAX(ds.nome) ILIKE 'SV %' OR MAX(ds.nome) ILIKE 'SV_%' 
                    THEN SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 1) || ' ' || SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 2)
                    ELSE SPLIT_PART(MAX(ds.nome), ' ', 1) 
                END, 
                c.codsupervisor
            ) as dimension,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10) THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN c.ano = $1 AND c.mes = $2 AND c.vlvenda >= 1 THEN c.codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN c.ano = $5 AND c.mes = $6 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $7 AND c.mes = $8 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $9 AND c.mes = $10 AND c.vlvenda >= 1 THEN c.codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN c.ano = $3 AND c.mes = $4 AND c.vlvenda >= 1 THEN c.codcli END) as pos_ant
        FROM classified_data c
        LEFT JOIN dim_supervisores ds ON c.codsupervisor = ds.codigo
        GROUP BY c.filial, c.codsupervisor, c.line_group
        HAVING SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) > 0
    ),

    -- REDES AGGREGATION
    agg_redes AS (
         SELECT
            'Geral' as group_name,
            'Rede: ' || dc.ramo as dimension,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10) THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_ant,
            COUNT(DISTINCT CASE WHEN c.ano = $1 AND c.mes = $2 AND c.vlvenda >= 1 THEN c.codcli END) as pos_atual,
            (COUNT(DISTINCT CASE WHEN c.ano = $5 AND c.mes = $6 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $7 AND c.mes = $8 AND c.vlvenda >= 1 THEN c.codcli END) + COUNT(DISTINCT CASE WHEN c.ano = $9 AND c.mes = $10 AND c.vlvenda >= 1 THEN c.codcli END)) / 3.0 as pos_trim,
            COUNT(DISTINCT CASE WHEN c.ano = $3 AND c.mes = $4 AND c.vlvenda >= 1 THEN c.codcli END) as pos_ant
        FROM classified_data c
        INNER JOIN data_clients dc ON c.codcli = dc.codigo_cliente
        WHERE dc.ramo IS NOT NULL AND dc.ramo != ''
        GROUP BY dc.ramo
    ),

    -- TOP VENDEDORES WITH FULL BREAKDOWN
    top_vendedores_base AS (
        SELECT
            COALESCE(SPLIT_PART(MAX(dv.nome), ' ', 1), c.codusur) as vendedor,
            MAX(c.codsupervisor) as codsupervisor,
            COALESCE(
                CASE 
                    WHEN MAX(ds.nome) ILIKE 'SV %' OR MAX(ds.nome) ILIKE 'SV_%' 
                    THEN SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 1) || ' ' || SPLIT_PART(REPLACE(MAX(ds.nome), '_', ' '), ' ', 2)
                    ELSE SPLIT_PART(MAX(ds.nome), ' ', 1) 
                END, 
                MAX(c.codsupervisor)
            ) as supervisor_nome,
            c.codusur,
            
            -- GERAL
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10) THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.vlvenda ELSE 0 END) as fat_ant,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') THEN c.peso ELSE 0 END) as ton_ant,
            
            -- SALTY
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.line_group = 'Salty' THEN c.vlvenda ELSE 0 END) as fat_atual_salty,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.line_group = 'Salty' THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim_salty,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.line_group = 'Salty' THEN c.vlvenda ELSE 0 END) as fat_ant_salty,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Salty' THEN c.peso ELSE 0 END) as ton_atual_salty,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Salty' THEN c.peso ELSE 0 END) / 3.0 as ton_trim_salty,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Salty' THEN c.peso ELSE 0 END) as ton_ant_salty,

            -- FOODS
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.line_group = 'Foods' THEN c.vlvenda ELSE 0 END) as fat_atual_foods,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.line_group = 'Foods' THEN c.vlvenda ELSE 0 END) / 3.0 as fat_trim_foods,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.line_group = 'Foods' THEN c.vlvenda ELSE 0 END) as fat_ant_foods,
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Foods' THEN c.peso ELSE 0 END) as ton_atual_foods,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Foods' THEN c.peso ELSE 0 END) / 3.0 as ton_trim_foods,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 AND c.tipovenda NOT IN ('5', '11') AND c.line_group = 'Foods' THEN c.peso ELSE 0 END) as ton_ant_foods,

            -- DEVOLUCAO E BONIFICACAO
            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.devolucao ELSE 0 END) as dev_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) THEN c.devolucao ELSE 0 END) / 3.0 as dev_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.devolucao ELSE 0 END) as dev_ant,

            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.bonificacao ELSE 0 END) as bon_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) THEN c.bonificacao ELSE 0 END) / 3.0 as bon_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.bonificacao ELSE 0 END) as bon_ant,

            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.perdas ELSE 0 END) as per_atual,
            SUM(CASE WHEN ((c.ano = $5 AND c.mes = $6) OR (c.ano = $7 AND c.mes = $8) OR (c.ano = $9 AND c.mes = $10)) THEN c.perdas ELSE 0 END) / 3.0 as per_trim,
            SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.perdas ELSE 0 END) as per_ant,

            SUM(CASE WHEN c.ano = $1 AND c.mes = $2 THEN c.vlvenda ELSE 0 END) - SUM(CASE WHEN c.ano = $3 AND c.mes = $4 THEN c.vlvenda ELSE 0 END) as var_abs
        FROM classified_data c
        LEFT JOIN dim_vendedores dv ON c.codusur = dv.codigo
        LEFT JOIN dim_supervisores ds ON c.codsupervisor = ds.codigo
        WHERE c.codusur IS NOT NULL AND c.codusur != ''
          AND c.codsupervisor != '8'
          AND c.codusur NOT ILIKE 'INAT_%'
          AND c.codusur NOT ILIKE '%BALCÃO%'
          AND c.codusur NOT ILIKE '%VENDAS DIRETAS%'
        GROUP BY c.codusur, c.codsupervisor
    ),
    
    top_vendedores_pos AS (
        SELECT 
            codusur,
            COUNT(CASE WHEN ano = $1 AND mes = $2 AND sum_vlvenda >= 1 THEN 1 END) as pos_atual,
            (COUNT(CASE WHEN ano = $5 AND mes = $6 AND sum_vlvenda >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $7 AND mes = $8 AND sum_vlvenda >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $9 AND mes = $10 AND sum_vlvenda >= 1 THEN 1 END)) / 3.0 as pos_trim,
            COUNT(CASE WHEN ano = $3 AND mes = $4 AND sum_vlvenda >= 1 THEN 1 END) as pos_ant,

            COUNT(CASE WHEN ano = $1 AND mes = $2 AND sum_vlvenda_salty >= 1 THEN 1 END) as pos_atual_salty,
            (COUNT(CASE WHEN ano = $5 AND mes = $6 AND sum_vlvenda_salty >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $7 AND mes = $8 AND sum_vlvenda_salty >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $9 AND mes = $10 AND sum_vlvenda_salty >= 1 THEN 1 END)) / 3.0 as pos_trim_salty,
            COUNT(CASE WHEN ano = $3 AND mes = $4 AND sum_vlvenda_salty >= 1 THEN 1 END) as pos_ant_salty,

            COUNT(CASE WHEN ano = $1 AND mes = $2 AND sum_vlvenda_foods >= 1 THEN 1 END) as pos_atual_foods,
            (COUNT(CASE WHEN ano = $5 AND mes = $6 AND sum_vlvenda_foods >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $7 AND mes = $8 AND sum_vlvenda_foods >= 1 THEN 1 END) + COUNT(CASE WHEN ano = $9 AND mes = $10 AND sum_vlvenda_foods >= 1 THEN 1 END)) / 3.0 as pos_trim_foods,
            COUNT(CASE WHEN ano = $3 AND mes = $4 AND sum_vlvenda_foods >= 1 THEN 1 END) as pos_ant_foods
        FROM grouped_pos
        GROUP BY codusur
    ),
    
    top_vendedores AS (
        SELECT 
            b.codusur, b.vendedor, b.codsupervisor, b.supervisor_nome,
            b.fat_atual, b.fat_trim, b.fat_ant, b.ton_atual, b.ton_trim, b.ton_ant,
            b.fat_atual_salty, b.fat_trim_salty, b.fat_ant_salty, b.ton_atual_salty, b.ton_trim_salty, b.ton_ant_salty,
            b.fat_atual_foods, b.fat_trim_foods, b.fat_ant_foods, b.ton_atual_foods, b.ton_trim_foods, b.ton_ant_foods, b.var_abs, b.dev_atual, b.dev_trim, b.dev_ant, b.bon_atual, b.bon_trim, b.bon_ant, b.per_atual, b.per_trim, b.per_ant,
            COALESCE(p.pos_atual, 0) as pos_atual, COALESCE(p.pos_trim, 0) as pos_trim, COALESCE(p.pos_ant, 0) as pos_ant,
            COALESCE(p.pos_atual_salty, 0) as pos_atual_salty, COALESCE(p.pos_trim_salty, 0) as pos_trim_salty, COALESCE(p.pos_ant_salty, 0) as pos_ant_salty,
            COALESCE(p.pos_atual_foods, 0) as pos_atual_foods, COALESCE(p.pos_trim_foods, 0) as pos_trim_foods, COALESCE(p.pos_ant_foods, 0) as pos_ant_foods
        FROM top_vendedores_base b
        LEFT JOIN top_vendedores_pos p ON b.codusur = p.codusur
        WHERE ltrim(b.codusur::text, '0') <> '190'
    ),

    -- CATEGORIAS
    agg_categorias AS (
        SELECT
            b.filial,
            CASE
                WHEN b.categoria_produto = 'TODDY' THEN 'TODDY'
                WHEN b.categoria_produto = 'TODDYNHO' THEN 'TODDYNHO'
                WHEN b.categoria_produto ILIKE '%SKINY%' THEN 'SKINY'
                WHEN b.categoria_produto ILIKE '%CHEETOS%' THEN 'CHEETOS'
                WHEN b.categoria_produto ILIKE '%FANDANGOS%' THEN 'FANDANGOS'
                WHEN b.categoria_produto ILIKE '%DORITOS%' THEN 'DORITOS'
                WHEN b.categoria_produto ILIKE '%CEBOLITOS%' THEN 'CEBOLITOS'
                WHEN b.categoria_produto ILIKE '%RUFFLES%' THEN 'RUFFLES'
                WHEN b.categoria_produto ILIKE '%QUAKER%' THEN 'QUAKER'
                WHEN b.categoria_produto ILIKE '%KEROCOCO%' THEN 'KEROCOCO'
                ELSE NULL
            END as cat_name,
            SUM(CASE WHEN b.ano = $1 AND b.mes = $2 THEN b.vlvenda ELSE 0 END) as fat_atual,
            SUM(CASE WHEN (b.ano = $5 AND b.mes = $6) OR (b.ano = $7 AND b.mes = $8) OR (b.ano = $9 AND b.mes = $10) THEN b.vlvenda ELSE 0 END) / 3.0 as fat_trim
        FROM base_data b
        WHERE b.categoria_produto IS NOT NULL
        GROUP BY 1, 2
        HAVING CASE
                WHEN b.categoria_produto = 'TODDY' THEN 'TODDY'
                WHEN b.categoria_produto = 'TODDYNHO' THEN 'TODDYNHO'
                WHEN b.categoria_produto ILIKE '%SKINY%' THEN 'SKINY'
                WHEN b.categoria_produto ILIKE '%CHEETOS%' THEN 'CHEETOS'
                WHEN b.categoria_produto ILIKE '%FANDANGOS%' THEN 'FANDANGOS'
                WHEN b.categoria_produto ILIKE '%DORITOS%' THEN 'DORITOS'
                WHEN b.categoria_produto ILIKE '%CEBOLITOS%' THEN 'CEBOLITOS'
                WHEN b.categoria_produto ILIKE '%RUFFLES%' THEN 'RUFFLES'
                WHEN b.categoria_produto ILIKE '%QUAKER%' THEN 'QUAKER'
                WHEN b.categoria_produto ILIKE '%KEROCOCO%' THEN 'KEROCOCO'
                ELSE NULL
            END IS NOT NULL
    ),
    agg_chart AS (
        SELECT
            'Geral' as group_name,
            ano,
            mes,
            SUM(vlvenda) as faturamento
        FROM public.data_summary
        WHERE ano IN ($1, $3)
        GROUP BY ano, mes
        UNION ALL
        SELECT
            CASE 
                WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN 'Salty'
                ELSE 'Foods'
            END as group_name,
            ano,
            mes,
            SUM(vlvenda) as faturamento
        FROM public.data_summary
        WHERE ano IN ($1, $3)
        GROUP BY 
            CASE 
                WHEN LTRIM(codfor::text, '0') IN ('707', '708', '752') THEN 'Salty'
                ELSE 'Foods'
            END, ano, mes
    )


    -- CTE: categorias_base
    , categorias_base AS (
        SELECT
            ce.equipe,
            ds.codusur,
            ds.categoria_produto as categoria,
            ds.codcli,
            ds.ano,
            ds.mes,
            ds.vlvenda,
            ds.peso,
            ds.codfor
        FROM public.data_summary ds
        JOIN public.config_equipes ce ON LTRIM(ds.codsupervisor::text, '0') = ce.codsupervisor
        WHERE ds.ano IN ($1, $5, $7, $9)
          AND ds.categoria_produto IS NOT NULL
          AND ds.categoria_produto != ''
    )
    -- CTE: categorias_disputa_raw
    , categorias_disputa_raw AS (
        SELECT
            cb.categoria,
            cb.equipe,
            cb.ano,
            cb.mes,
            SUM(cb.vlvenda) as faturamento,
            SUM(cb.peso) as tonelada,
            COUNT(DISTINCT cb.codcli) as posituacoes
        FROM categorias_base cb
        GROUP BY cb.categoria, cb.equipe, cb.ano, cb.mes
    )
    -- CTE: categorias_disputa_aggregated
    , categorias_disputa_aggregated AS (
        SELECT
            categoria,
            equipe,
            -- Current Month
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN faturamento ELSE 0 END) as fat_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN tonelada ELSE 0 END) as ton_atual,
            SUM(CASE WHEN ano = $1 AND mes = $2 THEN posituacoes ELSE 0 END) as pos_atual,
            -- Previous Quarter (Average)
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN faturamento ELSE 0 END) / 3.0 as fat_trim,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN tonelada ELSE 0 END) / 3.0 as ton_trim,
            SUM(CASE WHEN (ano = $5 AND mes = $6) OR (ano = $7 AND mes = $8) OR (ano = $9 AND mes = $10) THEN posituacoes ELSE 0 END) / 3.0 as pos_trim
        FROM categorias_disputa_raw
        GROUP BY categoria, equipe
    )
    -- Monthly distinct clients must be counted before averaging the previous three months.
    , vendedores_categorias_mensal AS (
        SELECT cb.equipe, cb.codusur, cb.ano, cb.mes,
            MAX(dv.nome) as vendedor,
            COUNT(DISTINCT cb.categoria) as categorias_distintas,
            SUM(cb.vlvenda) as faturamento,
            SUM(cb.peso) as tonelada,
            COUNT(DISTINCT cb.codcli) as posituacoes
        FROM categorias_base cb
        LEFT JOIN public.dim_vendedores dv ON LTRIM(cb.codusur::text, '0') = dv.codigo
        WHERE (cb.ano = $1 AND cb.mes = $2)
           OR (cb.ano = $5 AND cb.mes = $6)
           OR (cb.ano = $7 AND cb.mes = $8)
           OR (cb.ano = $9 AND cb.mes = $10)
        GROUP BY cb.equipe, cb.codusur, cb.ano, cb.mes
    ),
    vendedores_categorias AS (
        SELECT equipe, codusur, MAX(vendedor) as vendedor,
            COALESCE(MAX(categorias_distintas) FILTER (WHERE ano = $1 AND mes = $2), 0) as categorias_distintas,
            COALESCE(SUM(faturamento) FILTER (WHERE ano = $1 AND mes = $2), 0) as faturamento,
            COALESCE(SUM(tonelada) FILTER (WHERE ano = $1 AND mes = $2), 0) as tonelada,
            COALESCE(SUM(posituacoes) FILTER (WHERE ano = $1 AND mes = $2), 0) as posituacoes,
            COALESCE(SUM(faturamento) FILTER (WHERE NOT (ano = $1 AND mes = $2)), 0) / 3.0 as fat_trim,
            COALESCE(SUM(tonelada) FILTER (WHERE NOT (ano = $1 AND mes = $2)), 0) / 3.0 as ton_trim,
            COALESCE(SUM(posituacoes) FILTER (WHERE NOT (ano = $1 AND mes = $2)), 0) / 3.0 as pos_trim
        FROM vendedores_categorias_mensal
        GROUP BY equipe, codusur
    )
    -- CTE: kpi_salty
    , kpi_salty AS (
        SELECT
            cb.equipe,
            COUNT(DISTINCT cb.codcli) as clientes_salty
        FROM categorias_base cb
        WHERE cb.ano = $1 AND cb.mes = $2
          AND LTRIM(cb.codfor::text, '0') IN ('707', '708', '752')
        GROUP BY cb.equipe
    )


    SELECT json_build_object(
        'meta', json_build_object(
            'curr', json_build_object('ano', $1, 'mes', $2),
            'prev_y', json_build_object('ano', $3, 'mes', $4),
            'prev_q', json_build_object('q1_ano', $5, 'q1_mes', $6, 'q2_ano', $7, 'q2_mes', $8, 'q3_ano', $9, 'q3_mes', $10)
        ),
        'global', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_global a),
        'filiais', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_filial a),
        'supervisores', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_supervisor a),
        'redes', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_redes a),
        'top_vendedores', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM top_vendedores a),
        'categorias', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_categorias a),
        'chart_data', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM agg_chart a),
        'categorias_disputa', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM categorias_disputa_aggregated a),
        'vendedores_categorias', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM vendedores_categorias a),
        'kpi_salty', (SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) FROM kpi_salty a)
    )
    $dyn$ INTO v_result
    USING
        v_target_year, v_target_month,        -- $1, $2
        v_prev_year_year, v_prev_year_month,  -- $3, $4
        v_prev_q1_year, v_prev_q1_month,      -- $5, $6
        v_prev_q2_year, v_prev_q2_month,      -- $7, $8
        v_prev_q3_year, v_prev_q3_month;      -- $9, $10

    RETURN COALESCE(v_result, '{}'::json);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_loja_perfeita_data(p_filial text[] DEFAULT NULL::text[], p_cidade text[] DEFAULT NULL::text[], p_supervisor text[] DEFAULT NULL::text[], p_vendedor text[] DEFAULT NULL::text[], p_rede text[] DEFAULT NULL::text[], p_codcli text DEFAULT NULL::text, p_ano integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer, p_pesquisador text[] DEFAULT NULL::text[])
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_result json;
    
    v_where_base text := '1=1';
    v_where_chart text := '1=1';
    v_sql text;
    v_rede_condition text := '';
    v_has_com_rede boolean := false;
    v_has_sem_rede boolean := false;
    v_specific_redes text[];
BEGIN
    PERFORM private.evolution_assert_approved();
    -- Base Filters
    IF p_codcli IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND (codcli ILIKE %L OR client_name ILIKE %L)', '%' || p_codcli || '%', '%' || p_codcli || '%');
        v_where_chart := v_where_chart || format(' AND (codcli ILIKE %L OR client_name ILIKE %L)', '%' || p_codcli || '%', '%' || p_codcli || '%');
    END IF;

    IF p_ano IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND ano = %L', p_ano);
        v_where_chart := v_where_chart || format(' AND ano = %L', p_ano);
    END IF;

    IF p_mes IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND mes = %L', p_mes);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND city = ANY(%L::text[])', p_cidade);
        v_where_chart := v_where_chart || format(' AND city = ANY(%L::text[])', p_cidade);
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_has_com_rede := ('C/ REDE' = ANY(p_rede));
        v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
        v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

        IF array_length(v_specific_redes, 1) > 0 THEN
            v_rede_condition := format('ramo = ANY(%L::text[])', v_specific_redes);
        END IF;

        IF v_has_com_rede THEN
            IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
            v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND btrim(ramo) NOT IN ('''', ''--'', ''N/A'', ''N/D'')) ';
        END IF;

        IF v_has_sem_rede THEN
            IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
            v_rede_condition := v_rede_condition || ' (ramo IS NULL OR btrim(ramo) IN ('''', ''--'', ''N/A'', ''N/D'')) ';
        END IF;

        IF v_rede_condition != '' THEN
            v_where_base := v_where_base || ' AND (' || v_rede_condition || ') ';
            v_where_chart := v_where_chart || ' AND (' || v_rede_condition || ') ';
        END IF;
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND vendedor = ANY(%L::text[])', p_vendedor);
        v_where_chart := v_where_chart || format(' AND vendedor = ANY(%L::text[])', p_vendedor);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND supervisor = ANY(%L::text[])', p_supervisor);
        v_where_chart := v_where_chart || format(' AND supervisor = ANY(%L::text[])', p_supervisor);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND filial = ANY(%L::text[])', p_filial);
        v_where_chart := v_where_chart || format(' AND filial = ANY(%L::text[])', p_filial);
    END IF;

    IF p_pesquisador IS NOT NULL AND array_length(p_pesquisador, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND researcher = ANY(%L::text[])', p_pesquisador);
        v_where_chart := v_where_chart || format(' AND researcher = ANY(%L::text[])', p_pesquisador);
    END IF;

    v_sql := format('

        -- ⚡ [QueryTuner] Optimization: Emulated a Loose Index Scan (Skip Scan) using WITH RECURSIVE.
        -- PostgreSQL lacks native skip scans. A normal DISTINCT ON (codcli) on 1M rows still scans/sorts
        -- heavily. This recursive CTE jumps explicitly to the next distinct value via the B-Tree index,
        -- dropping execution time significantly for massive duplicate sets (e.g. ~800ms -> ~20ms).
        WITH RECURSIVE
        t AS (
            SELECT MIN(codcli) AS codcli FROM public.data_summary_frequency
            UNION ALL
            SELECT (SELECT MIN(codcli) FROM public.data_summary_frequency WHERE codcli > t.codcli)
            FROM t WHERE t.codcli IS NOT NULL
        ),
        client_ids AS (
            SELECT codcli FROM t WHERE codcli IS NOT NULL
        ),
        client_mapping AS (
            SELECT sub.codcli, sub.codsupervisor, sub.codusur, sub.filial
            FROM client_ids c
            LEFT JOIN LATERAL (
                SELECT d.codcli, d.codsupervisor, d.codusur, d.filial
                FROM public.data_summary_frequency d
                WHERE d.codcli = c.codcli
                ORDER BY d.codcli, d.ano DESC, d.mes DESC, d.created_at DESC
                LIMIT 1
            ) sub ON true
        ),
        base_data AS (
            SELECT 
                np.codigo_cliente as codcli,
                dc.nomecliente as client_name,
                final_researcher.researcher_name as researcher,
                CASE WHEN rri.tipo = ''rca'' THEN rri.cod_system END as researcher_vendor_code,
                dc.cidade as city,
                dc.ramo,
                dv.nome as vendedor,
                ds.nome as supervisor,
                cb.filial,
                np.nota_media as score,
                np.auditorias,
                np.auditorias_perfeitas,
                np.mes,
                np.ano
            FROM public.data_nota_perfeita np
            LEFT JOIN (SELECT DISTINCT tipo, cod_system, cod_involves FROM public.relacao_rota_involves) rri ON np.pesquisador = (CASE WHEN rri.tipo = ''promotor'' THEN rri.cod_system ELSE rri.cod_involves END)
            LEFT JOIN public.dim_vendedores dv_rca ON rri.tipo = ''rca'' AND rri.cod_system = dv_rca.codigo
            CROSS JOIN LATERAL (
                SELECT COALESCE(
                    CASE
                        WHEN rri.tipo = ''promotor'' THEN rri.cod_involves
                        WHEN rri.tipo = ''rca'' THEN dv_rca.nome
                    END,
                    np.pesquisador
                ) as researcher_name
            ) final_researcher
            LEFT JOIN public.data_clients dc ON np.codigo_cliente = dc.codigo_cliente
            LEFT JOIN public.config_city_branches cb ON dc.cidade = cb.cidade
            LEFT JOIN client_mapping cm ON np.codigo_cliente = cm.codcli
            LEFT JOIN public.dim_vendedores dv ON cm.codusur = dv.codigo
            LEFT JOIN public.dim_supervisores ds ON cm.codsupervisor = ds.codigo
        ),
        filtered_data AS (
            SELECT * FROM base_data WHERE %s
        ),
        chart_filtered_data AS (
            SELECT * FROM base_data WHERE %s
        ),
        kpi_client_avgs AS (
            SELECT codcli, AVG(score) as avg_score
            FROM filtered_data
            GROUP BY codcli
        ),
        kpis AS (
            SELECT 
                COALESCE(AVG(avg_score), 0) as avg_score,
                COUNT(codcli) as total_audits,
                COUNT(CASE WHEN avg_score >= 80 THEN codcli END) as perfect_stores
            FROM kpi_client_avgs
        ),
        chart_client_month_avgs AS (
            SELECT mes, codcli, AVG(score) as avg_score
            FROM chart_filtered_data
            GROUP BY mes, codcli
        ),
        chart_data AS (
            SELECT
                mes,
                COALESCE(AVG(avg_score), 0) as avg_score,
                COUNT(codcli) as total_audits,
                COUNT(CASE WHEN avg_score >= 80 THEN codcli END) as perfect_stores
            FROM chart_client_month_avgs
            GROUP BY mes
            ORDER BY mes
        ),
        chart_json AS (
            SELECT json_agg(
                json_build_object(
                    ''mes'', mes,
                    ''avg_score'', avg_score,
                    ''total_audits'', total_audits,
                    ''perfect_stores'', perfect_stores
                )
            ) as chart_array
            FROM chart_data
        ),
        researcher_client_avgs AS (
            SELECT researcher, codcli,
                SUM(score * GREATEST(COALESCE(auditorias, 1), 1)) / NULLIF(SUM(GREATEST(COALESCE(auditorias, 1), 1)), 0) AS avg_score,
                SUM(GREATEST(COALESCE(auditorias, 1), 1)) AS audits
            FROM filtered_data WHERE COALESCE(ltrim(researcher_vendor_code, ''0''), '''') <> ''190'' AND score IS NOT NULL AND NULLIF(btrim(researcher), '''') IS NOT NULL
            GROUP BY researcher, codcli
        ),
        researcher_ranking AS (
            SELECT researcher, AVG(avg_score) AS avg_score, COUNT(*) AS clients, SUM(audits) AS audits
            FROM researcher_client_avgs GROUP BY researcher
            ORDER BY AVG(avg_score) DESC, researcher LIMIT 10
        ),
        filter_options AS (
            SELECT json_build_object(
                ''combinations'', COALESCE((SELECT json_agg(x) FROM (SELECT DISTINCT filial AS filiais, supervisor AS supervisores, vendedor AS vendedores, ramo AS redes, city AS cidades, researcher AS pesquisadores FROM base_data WHERE ($1 IS NULL OR ano = $1) AND ($2 IS NULL OR mes = $2)) x), ''[]''::json),
                ''filiais'', COALESCE(json_agg(DISTINCT filial) FILTER (WHERE filial IS NOT NULL), ''[]''::json),
                ''supervisores'', COALESCE(json_agg(DISTINCT supervisor) FILTER (WHERE supervisor IS NOT NULL), ''[]''::json),
                ''vendedores'', COALESCE(json_agg(DISTINCT vendedor) FILTER (WHERE vendedor IS NOT NULL), ''[]''::json),
                ''redes'', COALESCE(json_agg(DISTINCT ramo) FILTER (WHERE NULLIF(btrim(ramo), '''') IS NOT NULL AND ramo NOT IN (''--'', ''N/A'', ''N/D'')), ''[]''::json),
                ''cidades'', COALESCE(json_agg(DISTINCT city) FILTER (WHERE city IS NOT NULL), ''[]''::json),
                ''pesquisadores'', COALESCE(json_agg(DISTINCT researcher) FILTER (WHERE researcher IS NOT NULL), ''[]''::json)
            ) AS options FROM base_data WHERE ($1 IS NULL OR ano = $1)
        ),
        clients_json AS (
            SELECT json_agg(
                json_build_object(
                    ''codcli'', codcli,
                    ''client_name'', COALESCE(client_name, ''Cliente Desconhecido''),
                    ''researcher'', COALESCE(researcher, ''--''),
                    ''city'', COALESCE(city, ''--''),
                    ''filial'', COALESCE(filial, ''--''),
                    ''supervisor'', COALESCE(supervisor, ''--''),
                    ''vendedor'', COALESCE(vendedor, ''--''),
                    ''rede'', COALESCE(ramo, ''--''),
                    ''score'', score
                ) ORDER BY score DESC
            ) as clients_array
            FROM filtered_data
        )
        SELECT json_build_object(
            ''kpis'', (SELECT row_to_json(kpis.*) FROM kpis),
            ''chart_data'', COALESCE((SELECT chart_array FROM chart_json), ''[]''::json),
            ''filter_options'', (SELECT options FROM filter_options),
            ''researcher_ranking'', COALESCE((SELECT json_agg(r ORDER BY avg_score DESC, researcher) FROM researcher_ranking r), ''[]''::json),
            ''clients'', COALESCE((SELECT clients_array FROM clients_json), ''[]''::json)
        )
    ', v_where_base, v_where_chart);

    EXECUTE v_sql INTO v_result USING p_ano, p_mes;

    RETURN v_result;
END;
$function$;

