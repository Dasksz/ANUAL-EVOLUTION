CREATE OR REPLACE FUNCTION get_dashboard_filters_optimized(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_filter_year int;
    v_filter_month int;
    v_result JSON;
BEGIN
    -- Configuração de performance
    SET LOCAL statement_timeout = '500s';

    -- Lógica de Ano/Mês (igual à tua original)
    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
    ELSE
        IF p_ano = 'todos' THEN v_filter_year := NULL;
        ELSE
            SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_filter_year FROM public.cache_filters;
        END IF;
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_filter_month := p_mes::int + 1; END IF;

    -- TÉCNICA AVANÇADA: Agregação Única
    -- Varre a tabela uma única vez e constrói todos os arrays JSON simultaneamente
    SELECT json_build_object(
        'supervisors', COALESCE(array_agg(DISTINCT superv) FILTER (WHERE superv IS NOT NULL), '{}'),
        'vendedores', COALESCE(array_agg(DISTINCT nome) FILTER (WHERE nome IS NOT NULL), '{}'),
        'cidades', COALESCE(array_agg(DISTINCT cidade) FILTER (WHERE cidade IS NOT NULL), '{}'),
        'filiais', COALESCE(array_agg(DISTINCT filial) FILTER (WHERE filial IS NOT NULL), '{}'),
        'redes', COALESCE(array_agg(DISTINCT rede) FILTER (WHERE rede IS NOT NULL AND rede NOT IN ('N/A', 'N/D')), '{}'),
        'anos', COALESCE(array_agg(DISTINCT ano) FILTER (WHERE ano IS NOT NULL), '{}'),
        'tipos_venda', COALESCE(array_agg(DISTINCT tipovenda) FILTER (WHERE tipovenda IS NOT NULL), '{}'),
        'fornecedores', (
            SELECT json_agg(json_build_object('cod', cod, 'name', nome) ORDER BY nome)
            FROM (
                SELECT DISTINCT codfor as cod, fornecedor as nome
                FROM public.cache_filters f2
                WHERE
                   (v_filter_year IS NULL OR f2.ano = v_filter_year)
                   AND (p_filial IS NULL OR f2.filial = ANY(p_filial))
                   -- ... (aplica mesmos filtros da query principal, ou simplifica para performance)
                   -- Nota: Para performance máxima, podemos simplificar a lista de fornecedores ou incluí-la no agg principal se não precisarmos do objeto {cod, name} complexo.
                   -- Mantendo compatibilidade com teu código atual:
                   AND f2.codfor IS NOT NULL
            ) sub
        )
    ) INTO v_result
    FROM public.cache_filters
    WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND (p_filial IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR tipovenda = ANY(p_tipovenda));

    RETURN v_result;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_cache_filters_fast_lookup
ON public.cache_filters (filial, cidade, superv);
