-- Drop the old function signature to avoid ambiguity (optional but recommended if not using overload)
DROP FUNCTION IF EXISTS get_city_view_data(text[], text[], text[], text[], text[], text, text, text[], int, int);

-- Create the updated function with new parameters
CREATE OR REPLACE FUNCTION get_city_view_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_page int default 0,
    p_limit int default 50,
    p_inactive_page int default 0,
    p_inactive_limit int default 50
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_year int;
    v_target_month int;
    v_start_date date;
    v_end_date date;
    v_result json;
    v_active_clients json;
    v_inactive_clients json;
    v_total_active_count int;
    v_total_inactive_count int;
BEGIN
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
         SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_target_month := p_mes::int + 1;
    ELSE SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year; END IF;

    v_start_date := make_date(v_current_year, v_target_month, 1);
    v_end_date := v_start_date + interval '1 month';

    -- Active Clients (Paginated)
    -- Using WITH clause to aggregate first
    WITH client_totals AS (
        SELECT codcli, SUM(vlvenda) as total_fat
        FROM public.data_summary
        WHERE ano = v_current_year
          AND (p_mes IS NULL OR p_mes = '' OR p_mes = 'todos' OR mes = (p_mes::int + 1))
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        GROUP BY codcli
        HAVING SUM(vlvenda) >= 1
    ),
    count_cte AS (SELECT COUNT(*) as cnt FROM client_totals),
    paginated_clients AS (
        SELECT ct.codcli, ct.total_fat, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.rca1, c.rca2
        FROM client_totals ct
        JOIN public.data_clients c ON c.codigo_cliente = ct.codcli
        ORDER BY ct.total_fat DESC
        LIMIT p_limit OFFSET (p_page * p_limit)
    )
    SELECT (SELECT cnt FROM count_cte), json_agg(json_build_object('Código', pc.codcli, 'fantasia', pc.fantasia, 'razaoSocial', pc.razaosocial, 'totalFaturamento', pc.total_fat, 'cidade', pc.cidade, 'bairro', pc.bairro, 'rca1', pc.rca1, 'rca2', pc.rca2) ORDER BY pc.total_fat DESC)
    INTO v_total_active_count, v_active_clients
    FROM paginated_clients pc;

    -- Inactive Clients (Paginated)
    WITH inactive_cte AS (
        SELECT c.codigo_cliente, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.ultimacompra, c.rca1, c.rca2
        FROM public.data_clients c
        WHERE c.bloqueio != 'S'
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR c.cidade = ANY(p_cidade))
          AND NOT EXISTS (
              SELECT 1 FROM public.data_summary s2
              WHERE s2.codcli = c.codigo_cliente
                AND s2.ano = v_current_year
                AND (p_mes IS NULL OR p_mes = '' OR p_mes = 'todos' OR s2.mes = (p_mes::int + 1))
                AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR s2.filial = ANY(p_filial))
                AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR s2.cidade = ANY(p_cidade))
                AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR s2.superv = ANY(p_supervisor))
                AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR s2.nome = ANY(p_vendedor))
                AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR s2.codfor = ANY(p_fornecedor))
                AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR s2.tipovenda = ANY(p_tipovenda))
          )
    ),
    count_inactive AS (SELECT COUNT(*) as cnt FROM inactive_cte),
    paginated_inactive AS (
        SELECT * FROM inactive_cte
        ORDER BY ultimacompra DESC NULLS LAST
        LIMIT p_inactive_limit OFFSET (p_inactive_page * p_inactive_limit)
    )
    SELECT (SELECT cnt FROM count_inactive), json_agg(
        json_build_object('Código', pi.codigo_cliente, 'fantasia', pi.fantasia, 'razaoSocial', pi.razaosocial, 'cidade', pi.cidade, 'bairro', pi.bairro, 'ultimaCompra', pi.ultimacompra, 'rca1', pi.rca1, 'rca2', pi.rca2)
        ORDER BY pi.ultimacompra DESC NULLS LAST
    ) INTO v_total_inactive_count, v_inactive_clients
    FROM paginated_inactive pi;

    v_result := json_build_object(
        'active_clients', COALESCE(v_active_clients, '[]'::json),
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', COALESCE(v_inactive_clients, '[]'::json),
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
    RETURN v_result;
END;
$$;
