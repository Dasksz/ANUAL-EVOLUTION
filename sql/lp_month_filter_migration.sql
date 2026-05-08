-- Add ano and mes columns to data_nota_perfeita
ALTER TABLE public.data_nota_perfeita 
ADD COLUMN IF NOT EXISTS ano integer,
ADD COLUMN IF NOT EXISTS mes integer;

-- Index to optimize querying and deletion by month/year
CREATE INDEX IF NOT EXISTS idx_nota_perfeita_ano_mes ON public.data_nota_perfeita (ano, mes);

-- Update get_loja_perfeita_data to accept ano and mes
DROP FUNCTION IF EXISTS get_loja_perfeita_data(text[], text[], text[], text[], text[], text);

CREATE OR REPLACE FUNCTION get_loja_perfeita_data(
    p_filial text[] DEFAULT NULL,
    p_cidade text[] DEFAULT NULL,
    p_supervisor text[] DEFAULT NULL,
    p_vendedor text[] DEFAULT NULL,
    p_rede text[] DEFAULT NULL,
    p_codcli text DEFAULT NULL,
    p_ano integer DEFAULT NULL,
    p_mes integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

    IF p_ano IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND np.ano = %L', p_ano);
    END IF;

    IF p_mes IS NOT NULL THEN
        v_where_base := v_where_base || format(' AND np.mes = %L', p_mes);
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
        v_where_base := v_where_base || format(' AND cb.filial = ANY(%L::text[])', p_filial);
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
            LEFT JOIN public.config_city_branches cb ON dc.cidade = cb.cidade
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
GRANT EXECUTE ON FUNCTION public.get_loja_perfeita_data(text[], text[], text[], text[], text[], text, integer, integer) TO authenticated, anon;

-- Backfill data based on mes_ano
UPDATE public.data_nota_perfeita
SET ano = CAST(SUBSTRING(mes_ano FROM '[0-9]{4}') AS INTEGER),
    mes = CASE
        WHEN LOWER(mes_ano) LIKE '%janeiro%' THEN 1
        WHEN LOWER(mes_ano) LIKE '%fevereiro%' THEN 2
        WHEN LOWER(mes_ano) LIKE '%março%' OR LOWER(mes_ano) LIKE '%marco%' THEN 3
        WHEN LOWER(mes_ano) LIKE '%abril%' THEN 4
        WHEN LOWER(mes_ano) LIKE '%maio%' THEN 5
        WHEN LOWER(mes_ano) LIKE '%junho%' THEN 6
        WHEN LOWER(mes_ano) LIKE '%julho%' THEN 7
        WHEN LOWER(mes_ano) LIKE '%agosto%' THEN 8
        WHEN LOWER(mes_ano) LIKE '%setembro%' THEN 9
        WHEN LOWER(mes_ano) LIKE '%outubro%' THEN 10
        WHEN LOWER(mes_ano) LIKE '%novembro%' THEN 11
        WHEN LOWER(mes_ano) LIKE '%dezembro%' THEN 12
    END
WHERE ano IS NULL OR mes IS NULL;

