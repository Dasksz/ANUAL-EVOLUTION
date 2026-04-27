
-- =========================================================================================
-- FUNÇÃO: get_loja_perfeita_data
-- DESCRIÇÃO: Retorna os KPIs e tabela detalhada da Loja Perfeita.
-- =========================================================================================
CREATE OR REPLACE FUNCTION get_loja_perfeita_data(
    p_filial text[] DEFAULT NULL,
    p_cidade text[] DEFAULT NULL,
    p_supervisor text[] DEFAULT NULL,
    p_vendedor text[] DEFAULT NULL,
    p_rede text[] DEFAULT NULL,
    p_codcli text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result json;

    v_where_base text := '1=1';
    v_sql text;
BEGIN
    -- Base Filters
    IF p_codcli IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND np.codigo_cliente = %L', p_codcli);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND dc.cidade = ANY(%L::text[])', p_cidade);
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF 'S/ REDE' = ANY(p_rede) THEN
            v_where_base := v_where_base || format(' AND (dc.ramo = ANY(%L::text[]) OR dc.ramo IS NULL OR dc.ramo IN (''N/A'', ''N/D''))', p_rede);
        ELSE
            v_where_base := v_where_base || format(' AND dc.ramo = ANY(%L::text[])', p_rede);
        END IF;
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND dv.nome = ANY(%L::text[])', p_vendedor);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND ds.nome = ANY(%L::text[])', p_supervisor);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND cm.filial = ANY(%L::text[])', p_filial);
    END IF;

    v_sql := format('

        WITH latest_sales AS (
            SELECT
                codcli, codsupervisor, codusur, filial,
                ROW_NUMBER() OVER(PARTITION BY codcli ORDER BY ano DESC, mes DESC, created_at DESC) as rn
            FROM public.data_summary_frequency
        ),
        client_mapping AS (
            SELECT codcli, codsupervisor, codusur, filial
            FROM latest_sales
            WHERE rn = 1
        ),
        filtered_data AS (
            SELECT
                np.codigo_cliente as codcli,
                dc.nomecliente as client_name,
                np.pesquisador as researcher,
                dc.cidade as city,
                np.nota_media as score,
                np.auditorias,
                np.auditorias_perfeitas
            FROM public.data_nota_perfeita np
            LEFT JOIN public.data_clients dc ON np.codigo_cliente = dc.codigo_cliente
            LEFT JOIN client_mapping cm ON np.codigo_cliente = cm.codcli
            LEFT JOIN public.dim_vendedores dv ON cm.codusur = dv.codigo
            LEFT JOIN public.dim_supervisores ds ON cm.codsupervisor = ds.codigo
            WHERE %s
        ),
        kpis AS (
            SELECT
                COALESCE(AVG(score), 0) as avg_score,
                COUNT(DISTINCT codcli) as total_audits,
                COUNT(DISTINCT CASE WHEN score >= 80 THEN codcli END) as perfect_stores
            FROM filtered_data
        ),
        clients_json AS (
            SELECT json_agg(
                json_build_object(
                    ''codcli'', codcli,
                    ''client_name'', COALESCE(client_name, ''Cliente Desconhecido''),
                    ''researcher'', COALESCE(researcher, ''--''),
                    ''city'', COALESCE(city, ''--''),
                    ''score'', score
                ) ORDER BY score DESC
            ) as clients_array
            FROM filtered_data
        )
        SELECT json_build_object(
            ''kpis'', (SELECT row_to_json(kpis.*) FROM kpis),
            ''clients'', COALESCE((SELECT clients_array FROM clients_json), ''[]''::json)
        )
    ', v_where_base);

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$$;
