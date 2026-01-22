-- Migration to filter products dropdown by sales existence
-- 1. Create Indexes on Produto column for performance
CREATE INDEX IF NOT EXISTS idx_detailed_produto ON public.data_detailed (produto);
CREATE INDEX IF NOT EXISTS idx_history_produto ON public.data_history (produto);

-- 2. Update get_dashboard_filters to include sales check
CREATE OR REPLACE FUNCTION get_dashboard_filters(
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
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_supervisors text[];
    v_vendedores text[];
    v_fornecedores json;
    v_cidades text[];
    v_filiais text[];
    v_anos int[];
    v_tipos_venda text[];
    v_redes text[];
    v_produtos json; -- NEW
    v_filter_year int;
    v_filter_month int;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL statement_timeout = '300s';

    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
    ELSE
        IF p_ano = 'todos' THEN v_filter_year := NULL;
        ELSE
            SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_filter_year FROM public.cache_filters;
        END IF;
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_filter_month := p_mes::int + 1; END IF;

    -- 1. Supervisors
    SELECT ARRAY(SELECT DISTINCT superv FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND superv IS NOT NULL AND superv != '' AND superv != 'null'
        ORDER BY superv
    ) INTO v_supervisors;

    -- 2. Vendedores
    SELECT ARRAY(SELECT DISTINCT nome FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND nome IS NOT NULL AND nome != '' AND nome != 'null'
        ORDER BY nome
    ) INTO v_vendedores;

    -- 3. Cidades
    SELECT ARRAY(SELECT DISTINCT cidade FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND cidade IS NOT NULL AND cidade != '' AND cidade != 'null'
        ORDER BY cidade
    ) INTO v_cidades;

    -- 4. Filiais
    SELECT ARRAY(SELECT DISTINCT filial FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND filial IS NOT NULL AND filial != '' AND filial != 'null'
        ORDER BY filial
    ) INTO v_filiais;

    -- 5. Tipos de Venda
    SELECT ARRAY(SELECT DISTINCT tipovenda FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND tipovenda IS NOT NULL AND tipovenda != '' AND tipovenda != 'null'
        ORDER BY tipovenda
    ) INTO v_tipos_venda;

    -- 6. Fornecedores
    SELECT json_agg(json_build_object('cod', codfor, 'name', fornecedor) ORDER BY
        CASE
            WHEN codfor = '707' THEN 1
            WHEN codfor = '708' THEN 2
            WHEN codfor = '752' THEN 3
            WHEN codfor = '1119_TODDYNHO' THEN 4
            WHEN codfor = '1119_TODDY' THEN 5
            WHEN codfor = '1119_QUAKER' THEN 6
            WHEN codfor = '1119_KEROCOCO' THEN 7
            WHEN codfor = '1119_OUTROS' THEN 8
            ELSE 99
        END, fornecedor
    ) INTO v_fornecedores
    FROM (
        SELECT DISTINCT codfor, fornecedor FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND codfor IS NOT NULL
    ) t;

    -- 7. Redes
    SELECT ARRAY(SELECT DISTINCT rede FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND rede IS NOT NULL AND rede != '' AND rede != 'null' AND rede != 'N/A' AND rede != 'N/D'
        ORDER BY rede
    ) INTO v_redes;

    -- 8. Anos
    SELECT ARRAY(SELECT DISTINCT ano FROM public.cache_filters WHERE
        (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY ano DESC
    ) INTO v_anos;

    -- 9. Produtos (Filtered by Fornecedor AND Sales Existence)
    SELECT json_agg(json_build_object('cod', codigo, 'name', descricao || ' (' || codigo || ')') ORDER BY descricao)
    INTO v_produtos
    FROM public.dim_produtos
    WHERE (
        CASE
            WHEN p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
                CASE
                   -- Special Handling for 1119 subtypes
                   WHEN '1119_TODDYNHO' = ANY(p_fornecedor) OR '1119_TODDY' = ANY(p_fornecedor) OR '1119_QUAKER' = ANY(p_fornecedor) OR '1119_KEROCOCO' = ANY(p_fornecedor) OR '1119_OUTROS' = ANY(p_fornecedor) THEN
                       codfor = '1119' OR codfor = ANY(p_fornecedor)
                   ELSE
                       codfor = ANY(p_fornecedor)
                END
            ELSE 1=1
        END
    )
    -- NEW: Filter to only include products that have sales
    AND (
        EXISTS (SELECT 1 FROM public.data_detailed d WHERE d.produto = public.dim_produtos.codigo)
        OR
        EXISTS (SELECT 1 FROM public.data_history h WHERE h.produto = public.dim_produtos.codigo)
    );

    RETURN json_build_object(
        'supervisors', COALESCE(v_supervisors, '{}'),
        'vendedores', COALESCE(v_vendedores, '{}'),
        'fornecedores', COALESCE(v_fornecedores, '[]'::json),
        'cidades', COALESCE(v_cidades, '{}'),
        'filiais', COALESCE(v_filiais, '{}'),
        'redes', COALESCE(v_redes, '{}'),
        'anos', COALESCE(v_anos, '{}'),
        'tipos_venda', COALESCE(v_tipos_venda, '{}'),
        'produtos', COALESCE(v_produtos, '[]'::json)
    );
END;
$$;
