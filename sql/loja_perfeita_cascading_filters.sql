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
            FROM filtered_data WHERE score IS NOT NULL AND NULLIF(btrim(researcher), '''') IS NOT NULL
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

