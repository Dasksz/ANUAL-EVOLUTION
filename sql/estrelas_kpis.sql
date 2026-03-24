CREATE TABLE IF NOT EXISTS public.config_aceleradores (
    id SERIAL PRIMARY KEY,
    nome_categoria TEXT NOT NULL UNIQUE
);

CREATE OR REPLACE FUNCTION get_estrelas_kpis_data(
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
    v_current_year int;
    v_target_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_acel text := '';

    v_sql text;
    v_result json;
BEGIN
    SET LOCAL work_mem = '64MB';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary_frequency;
    ELSE
        v_current_year := p_ano::int;
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int;
        v_where_base := v_where_base || format(' AND s.ano = %L AND s.mes = %L ', v_current_year, v_target_month);
    ELSE
        v_where_base := v_where_base || format(' AND s.ano = %L ', v_current_year);
    END IF;

    -- 2. Build Where Clauses
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_base := v_where_base || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
            v_where_clients := v_where_clients || format(' AND dc.cidade IN (SELECT cidade FROM public.config_city_branches WHERE filial = ANY(%L::text[])) ', p_filial);
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND dc.cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM public.data_summary_frequency sf WHERE sf.codcli = dc.codigo_cliente AND sf.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        -- Client filtering logic simplified for exact matching where possible
        v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM public.data_summary_frequency sf WHERE sf.codcli = dc.codigo_cliente AND sf.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[]))) ', p_vendedor);
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.tipovenda = ANY(%L::text[]) ', p_tipovenda);
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF 'S/ REDE' = ANY(p_rede) THEN
            v_where_base := v_where_base || format(' AND (c.ramo = ANY(%L::text[]) OR c.ramo IS NULL OR c.ramo IN (''N/A'', ''N/D'')) ', p_rede);
            v_where_clients := v_where_clients || format(' AND (dc.ramo = ANY(%L::text[]) OR dc.ramo IS NULL OR dc.ramo IN (''N/A'', ''N/D'')) ', p_rede);
        ELSE
            v_where_base := v_where_base || format(' AND c.ramo = ANY(%L::text[]) ', p_rede);
            v_where_clients := v_where_clients || format(' AND dc.ramo = ANY(%L::text[]) ', p_rede);
        END IF;
    END IF;

    -- Note: Since we are calculating specific suppliers (707, 708, 752, 1119), p_fornecedor filter might override this if provided.
    -- If p_fornecedor is passed, we apply it. But usually, this view is specifically for Pepsico (707, 708, 752, 1119).
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codfor = ANY(%L::text[]) ', p_fornecedor);
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.categorias) c WHERE c = ANY(%L::text[])) ', p_categoria);
    END IF;


    v_sql := format('
        WITH base_clientes_cte AS (
            SELECT COUNT(codigo_cliente) as total_clientes
            FROM public.data_clients dc
            %s
        ),
        target_sales AS (
            SELECT s.*
            FROM public.data_summary_frequency s
            LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            %s
        ),
        sales_data AS (
            SELECT
                SUM(s.peso) as total_tonnage,
                -- Salty Tonnage
                SUM(CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.peso ELSE 0 END) as salty_tonnage,
                -- Foods Tonnage
                SUM(CASE WHEN s.codfor IN (''1119'') THEN s.peso ELSE 0 END) as foods_tonnage,

                -- Salty Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.codcli END) as positivacao_salty,
                -- Foods Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') THEN s.codcli END) as positivacao_foods
            FROM target_sales s
        ),
        aceleradores_config AS (
            SELECT array_agg(nome_categoria) as nomes FROM public.config_aceleradores
        ),
        aceleradores_calc AS (
            SELECT
                COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
                COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
            FROM target_sales s
        )
        SELECT json_build_object(
            ''base_clientes'', COALESCE((SELECT total_clientes FROM base_clientes_cte), 0),
            ''sellout_salty'', COALESCE((SELECT salty_tonnage / 1000.0 FROM sales_data), 0),
            ''sellout_foods'', COALESCE((SELECT foods_tonnage / 1000.0 FROM sales_data), 0),
            ''positivacao_salty'', COALESCE((SELECT positivacao_salty FROM sales_data), 0),
            ''positivacao_foods'', COALESCE((SELECT positivacao_foods FROM sales_data), 0),
            ''aceleradores_realizado'', COALESCE((SELECT aceleradores_realizado FROM aceleradores_calc), 0),
            ''aceleradores_parcial'', COALESCE((SELECT aceleradores_parcial FROM aceleradores_calc), 0)
        )
    ', v_where_clients, v_where_base);

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$$;
