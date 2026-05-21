CREATE OR REPLACE FUNCTION get_jbp_inovacoes_details(
    p_ano int,
    p_mes int,
    p_codcli text default null,
    p_rede text default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result json;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    -- Query directly from data_summary as it already contains inovacao_categoria and product data, wait, user said it crashed.
    -- The error was "column data_summary.cod_prod does not exist". 
    -- The actual columns are: `produto` (or no, `data_summary` has `categoria_produto`, `ano`, `mes`, `codcli`, `ramo` but NOT product details, it's summarized!). 
    -- We need to query from `data_history` + `data_detailed` joined with `data_innovations` and `dim_produtos`.
    
    WITH raw_sales AS (
        SELECT s.produto, inov.inovacoes as inovacao_categoria
        FROM data_detailed s
        JOIN data_innovations inov ON s.produto = inov.codigo
        LEFT JOIN data_clients c ON s.codcli = c.codigo_cliente
        WHERE EXTRACT(YEAR FROM s.dtped)::int = p_ano 
          AND EXTRACT(MONTH FROM s.dtped)::int = p_mes
          AND s.vlvenda > 0
          AND (p_codcli IS NULL OR s.codcli = p_codcli)
          AND (p_rede IS NULL OR c.ramo = p_rede)
        UNION ALL
        SELECT s.produto, inov.inovacoes as inovacao_categoria
        FROM data_history s
        JOIN data_innovations inov ON s.produto = inov.codigo
        LEFT JOIN data_clients c ON s.codcli = c.codigo_cliente
        WHERE EXTRACT(YEAR FROM s.dtped)::int = p_ano 
          AND EXTRACT(MONTH FROM s.dtped)::int = p_mes
          AND s.vlvenda > 0
          AND (p_codcli IS NULL OR s.codcli = p_codcli)
          AND (p_rede IS NULL OR c.ramo = p_rede)
    ),
    distinct_sales AS (
        SELECT DISTINCT rs.produto as cod_prod, p.descricao as nome_prod, rs.inovacao_categoria
        FROM raw_sales rs
        LEFT JOIN dim_produtos p ON rs.produto = p.codigo
    )
    SELECT COALESCE(json_agg(row_to_json(distinct_sales)), '[]'::json)
    INTO v_result
    FROM distinct_sales;
    
    RETURN v_result;
END;
$$;
