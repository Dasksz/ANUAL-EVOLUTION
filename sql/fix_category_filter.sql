
-- Fix Category Filter Self-Filtering Issue
-- This script updates get_dashboard_filters to prevent the category filter from filtering its own dropdown list.

CREATE OR REPLACE FUNCTION get_dashboard_filters(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_where text := ' WHERE 1=1 ';
    v_where_cat text := ' WHERE 1=1 '; -- NEW: Where clause specifically for Category List (excludes category filter)
    v_result json;
BEGIN
    -- Construct Common Where Clause Parts
    IF p_ano IS NOT NULL AND p_ano != 'todos' THEN
        v_where := v_where || format(' AND ano = %L ', p_ano::int);
        v_where_cat := v_where_cat || format(' AND ano = %L ', p_ano::int);
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_where := v_where || format(' AND mes = %L ', p_mes::int + 1);
        v_where_cat := v_where_cat || format(' AND mes = %L ', p_mes::int + 1);
    END IF;
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
        v_where_cat := v_where_cat || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_cat := v_where_cat || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND superv = ANY(%L) ', p_supervisor);
        v_where_cat := v_where_cat || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND nome = ANY(%L) ', p_vendedor);
        v_where_cat := v_where_cat || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
        v_where_cat := v_where_cat || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        v_where_cat := v_where_cat || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_where := v_where || format(' AND rede = ANY(%L) ', p_rede);
        v_where_cat := v_where_cat || format(' AND rede = ANY(%L) ', p_rede);
    END IF;

    -- Category Filter (Applied to main v_where, BUT NOT v_where_cat)
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- Execute with dynamic JSON construction
    -- Note: 'categorias' uses v_where_cat to remain independent of its own selection
    EXECUTE '
    SELECT json_build_object(
        ''anos'', (SELECT array_agg(DISTINCT ano ORDER BY ano DESC) FROM public.cache_filters),
        ''filiais'', (SELECT array_agg(DISTINCT filial ORDER BY filial) FROM public.cache_filters ' || v_where || '),
        ''cidades'', (SELECT array_agg(DISTINCT cidade ORDER BY cidade) FROM public.cache_filters ' || v_where || '),
        ''supervisors'', (SELECT array_agg(DISTINCT superv ORDER BY superv) FROM public.cache_filters ' || v_where || '),
        ''vendedores'', (SELECT array_agg(DISTINCT nome ORDER BY nome) FROM public.cache_filters ' || v_where || '),
        ''fornecedores'', (
            SELECT json_agg(DISTINCT jsonb_build_object(''cod'', codfor, ''name'', fornecedor))
            FROM public.cache_filters ' || v_where || '
        ),
        ''tipos_venda'', (SELECT array_agg(DISTINCT tipovenda ORDER BY tipovenda) FROM public.cache_filters ' || v_where || '),
        ''redes'', (SELECT array_agg(DISTINCT rede ORDER BY rede) FROM public.cache_filters ' || v_where || ' AND rede IS NOT NULL),
        ''categorias'', (SELECT array_agg(DISTINCT categoria_produto ORDER BY categoria_produto) FROM public.cache_filters ' || v_where_cat || ' AND categoria_produto IS NOT NULL)
    )' INTO v_result;

    RETURN v_result;
END;
$$;
