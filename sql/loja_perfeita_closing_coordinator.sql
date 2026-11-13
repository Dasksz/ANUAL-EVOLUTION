-- EVOLUTION: dedicated reader for the closing presentation; the dashboard RPC remains unchanged.
CREATE OR REPLACE FUNCTION private.loja_perfeita_coordinators_fetch_v1(p_codes text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE config jsonb;response extensions.http_response;result jsonb;old_timeout text;
BEGIN
 PERFORM private.evolution_assert_approved();
 IF cardinality(p_codes)>2500 THEN RAISE EXCEPTION 'Carteira inválida';END IF;
 SELECT decrypted_secret::jsonb INTO config FROM vault.decrypted_secrets WHERE name='planning_financial_bridge';
 IF config IS NULL THEN RAISE EXCEPTION 'Consulta de coordenadores não configurada';END IF;
 SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','10000');
 SELECT * INTO response FROM extensions.http(ROW('POST','https://dldsocponbjthqxhmttj.supabase.co/rest/v1/rpc/loja_perfeita_coordinators_source_v1',
 ARRAY[extensions.http_header('apikey',config->>'anon'),extensions.http_header('Authorization','Bearer '||(config->>'anon'))],
 'application/json',jsonb_build_object('p_codes',p_codes,'p_token',config->>'token')::text)::extensions.http_request);
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
 IF response.status<>200 THEN RAISE EXCEPTION 'Não foi possível consultar coordenadores (HTTP %). Tente novamente.',response.status;END IF;
 result:=response.content::jsonb;
 IF jsonb_typeof(result) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Retorno de coordenadores inválido'; END IF;
 RETURN result;
EXCEPTION WHEN OTHERS THEN
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));RAISE;
END;$$;
REVOKE ALL ON FUNCTION private.loja_perfeita_coordinators_fetch_v1(text[]) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_loja_perfeita_closing_data(p_filial text[] DEFAULT NULL::text[], p_cidade text[] DEFAULT NULL::text[], p_supervisor text[] DEFAULT NULL::text[], p_vendedor text[] DEFAULT NULL::text[], p_rede text[] DEFAULT NULL::text[], p_codcli text DEFAULT NULL::text, p_ano integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer, p_pesquisador text[] DEFAULT NULL::text[], p_coordenador text[] DEFAULT NULL::text[])
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_result json;
    v_coordinators jsonb;
    v_codes text[];
    
    v_where_base text := '1=1';
    v_where_chart text := '1=1';
    v_sql text;
    v_rede_condition text := '';
    v_has_com_rede boolean := false;
    v_has_sem_rede boolean := false;
    v_specific_redes text[];
BEGIN
    PERFORM private.evolution_assert_approved();
    SELECT array_agg(DISTINCT coalesce(nullif(ltrim(btrim(codigo_cliente),'0'),''),'0'))
    INTO v_codes FROM public.data_nota_perfeita
    WHERE (p_ano IS NULL OR ano=p_ano) AND btrim(codigo_cliente) ~ '^[0-9]{1,20}$';
    v_coordinators := CASE WHEN v_codes IS NULL THEN '{}'::jsonb ELSE private.loja_perfeita_coordinators_fetch_v1(v_codes) END;
    IF cardinality(p_coordenador)>0 THEN
        v_where_base := v_where_base || format(' AND coordenadores ?| %L::text[]',p_coordenador);
        v_where_chart := v_where_chart || format(' AND coordenadores ?| %L::text[]',p_coordenador);
    END IF;
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

        -- Read the current portfolio view once instead of recursively rescanning it.
        WITH client_mapping AS MATERIALIZED (
            SELECT DISTINCT ON (d.codcli)
                d.codcli, d.codsupervisor, d.codusur, d.filial
            FROM public.data_summary_frequency_current d
            WHERE d.codcli IN (
                SELECT codigo_cliente FROM public.data_nota_perfeita
            )
            ORDER BY d.codcli, d.ano DESC, d.mes DESC, d.created_at DESC
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
                coalesce($3->coalesce(nullif(ltrim(btrim(np.codigo_cliente),''0''),''''),''0''),''[]''::jsonb) AS coordenadores,
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
                ''combinations'', COALESCE((SELECT json_agg(x) FROM (SELECT DISTINCT filial AS filiais, supervisor AS supervisores, vendedor AS vendedores, ramo AS redes, city AS cidades, researcher AS pesquisadores, coordenadores FROM base_data WHERE ($1 IS NULL OR ano = $1) AND ($2 IS NULL OR mes = $2)) x), ''[]''::json),
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
                    ''coordenadores'', coordenadores,
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

    EXECUTE v_sql INTO v_result USING p_ano, p_mes, v_coordinators;

    RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_loja_perfeita_closing_data(text[],text[],text[],text[],text[],text,integer,integer,text[],text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_loja_perfeita_closing_data(text[],text[],text[],text[],text[],text,integer,integer,text[],text[]) TO authenticated;
NOTIFY pgrst, 'reload schema';
