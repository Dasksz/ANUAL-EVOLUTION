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
    v_eval_target_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_acel text := '';

    v_fornecedor_salty_cond text := 's.codfor IN (''707'', ''708'', ''752'')';
    v_fornecedor_foods_cond text := 's.codfor LIKE ''1119_%''';

    v_result json;
    v_sql text;
BEGIN
    SET LOCAL work_mem = '64MB';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary_frequency);
    ELSE
        v_current_year := p_ano::int;
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int;
        v_where_base := v_where_base || format(' AND s.ano = %L AND s.mes = %L ', v_current_year, v_target_month);
    ELSE
        v_where_base := v_where_base || format(' AND s.ano = %L ', v_current_year);
    END IF;

    v_eval_target_month := COALESCE(v_target_month, (SELECT COALESCE(MAX(mes), EXTRACT(MONTH FROM CURRENT_DATE)::int) FROM public.data_summary_frequency WHERE ano = v_current_year));

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
        v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM public.data_summary_frequency sf WHERE sf.codcli = dc.codigo_cliente AND sf.codusur IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_vendedor);
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.tipovenda = ANY(%L::text[]) ', p_tipovenda);
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF 'S/ REDE' = ANY(p_rede) THEN
            v_where_base := v_where_base || format(' AND (UPPER(c.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) OR c.ramo IS NULL OR c.ramo IN (''N/A'', ''N/D'')) ', p_rede);
            v_where_clients := v_where_clients || format(' AND (UPPER(dc.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) OR dc.ramo IS NULL OR dc.ramo IN (''N/A'', ''N/D'')) ', p_rede);
        ELSE
            v_where_base := v_where_base || format(' AND UPPER(c.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
            v_where_clients := v_where_clients || format(' AND UPPER(dc.ramo) = ANY(ARRAY(SELECT UPPER(x) FROM unnest(%L::text[]) x)) ', p_rede);
        END IF;
    END IF;

    -- Note: This view specifically calculates KPIs for Salty (707, 708, 752) and Foods (1119).
    -- If p_fornecedor is passed, we apply it inside the CTE calculation specifically for those blocks,
    -- or we use it to construct a base filter that ALWAYS includes the unselected block so that the
    -- dashboard doesn't blank out.
    -- E.g. If they filter Salty, we still need to load Foods to show 0/Realizado properly, OR we
    -- apply the filters directly on the SELECT metrics below.
    -- To ensure both KPIs always function properly independently, we will NOT filter out the base
    -- CTE by p_fornecedor here. We'll handle the p_fornecedor condition dynamically in the metrics calculation!
    
    BEGIN
        IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
            DECLARE
                v_code text;
                v_salty_codes text[] := '{}';
                v_foods_conds text[] := '{}';
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code IN ('707', '708', '752') THEN
                        v_salty_codes := array_append(v_salty_codes, v_code);
                    ELSIF v_code LIKE '1119_%' THEN
                        v_foods_conds := array_append(v_foods_conds, format('s.codfor = %L', v_code));
                    END IF;
                END LOOP;
                
                IF array_length(v_salty_codes, 1) > 0 THEN
                    v_fornecedor_salty_cond := format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_salty_codes, ''','''));
                ELSE
                    -- If filtering and NO salty codes were selected, salty metrics should be strictly zeroed out
                    -- ONLY if we are actually filtering suppliers.
                    v_fornecedor_salty_cond := 'FALSE';
                END IF;
                
                IF array_length(v_foods_conds, 1) > 0 THEN
                    v_fornecedor_foods_cond := '(' || array_to_string(v_foods_conds, ' OR ') || ')';
                ELSE
                    -- If filtering and NO foods codes were selected, foods metrics should be strictly zeroed out
                    v_fornecedor_foods_cond := 'FALSE';
                END IF;
            END;
        END IF;
    END;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(s.categorias) c WHERE c = ANY(%L::text[])) ', p_categoria);
    END IF;

    -- 3. Build Metas Where Clause
    DECLARE
        v_where_metas text := '';
    BEGIN
        IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
            IF NOT ('ambas' = ANY(p_filial)) THEN
                v_where_metas := v_where_metas || format(' AND m.filial::text = ANY(ARRAY(SELECT LTRIM(f, ''0'') FROM unnest(%L::text[]) AS f)) ', p_filial);
            END IF;
        END IF;

        IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
            v_where_metas := v_where_metas || format(' AND m.cod_rca::text IN (SELECT LTRIM(codigo, ''0'') FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        END IF;

        IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
            v_where_metas := v_where_metas || format(' AND m.cod_rca::text IN (
                SELECT DISTINCT LTRIM(rs.codusur, ''0'') FROM (
                    SELECT codusur, codsupervisor, ROW_NUMBER() OVER(PARTITION BY codusur ORDER BY dtped DESC) as rn
                    FROM (
                        SELECT codusur, codsupervisor, dtped FROM public.data_detailed
                        UNION ALL
                        SELECT codusur, codsupervisor, dtped FROM public.data_history
                    ) all_sales
                ) rs
                JOIN public.dim_supervisores ds ON rs.codsupervisor = ds.codigo
                WHERE rs.rn = 1 AND ds.nome = ANY(%L::text[])
            ) ', p_supervisor);
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
                SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as salty_tonnage,
                -- Foods Tonnage
                SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as foods_tonnage,

                -- Salty Positivacao
                COUNT(DISTINCT CASE WHEN %s AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_salty,
                -- Foods Positivacao (Strict logic: Bought Foods AND bought nothing else in the target table)
                COUNT(DISTINCT CASE WHEN NOT EXISTS (SELECT 1 FROM target_sales c WHERE c.codcli = s.codcli AND c.vlvenda >= 1 AND c.codfor NOT LIKE ''1119_%%'') AND EXISTS (SELECT 1 FROM target_sales c WHERE c.codcli = s.codcli AND c.vlvenda >= 1 AND %s) AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_foods
            FROM target_sales s
        ),
        aceleradores_config AS (
            SELECT array_agg(nome_categoria) as nomes FROM public.config_aceleradores
        ),
        aceleradores_calc AS (
            SELECT
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
            FROM target_sales s
        ),
        metas_calc AS (
            SELECT
                COALESCE(SUM(calibracao_salty), 0) as meta_salty,
                COALESCE(SUM(calibracao_foods), 0) as meta_foods,
                COALESCE(SUM(calibracao_pos), 0) as meta_pos
            FROM public.meta_estrelas m
            WHERE m.ano = %s AND m.mes = %s
            %s
        ),
        detalhes_calc AS (
            SELECT
                COALESCE(dv.nome, ''N/D'') AS vendedor_nome,
                s.filial,
                COALESCE(SUM(CASE WHEN %s THEN s.peso ELSE 0 END), 0) AS sellout_salty,
                COALESCE(SUM(CASE WHEN %s THEN s.peso ELSE 0 END), 0) AS sellout_foods,
                COUNT(DISTINCT CASE WHEN %s AND s.vlvenda >= 1 THEN s.codcli END) AS pos_salty,
                COUNT(DISTINCT CASE WHEN NOT EXISTS (SELECT 1 FROM target_sales c WHERE c.codcli = s.codcli AND c.vlvenda >= 1 AND c.codfor NOT LIKE ''1119_%%'') AND EXISTS (SELECT 1 FROM target_sales c WHERE c.codcli = s.codcli AND c.vlvenda >= 1 AND %s) AND s.vlvenda >= 1 THEN s.codcli END) AS pos_foods,
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) AS acel_realizado,
                COALESCE((SELECT SUM(m.calibracao_salty) FROM public.meta_estrelas m WHERE m.cod_rca::text = LTRIM(s.codusur, ''0'') AND m.filial::text = LTRIM(s.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_salty,
                COALESCE((SELECT SUM(m.calibracao_foods) FROM public.meta_estrelas m WHERE m.cod_rca::text = LTRIM(s.codusur, ''0'') AND m.filial::text = LTRIM(s.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_foods,
                COALESCE((SELECT SUM(m.calibracao_pos) FROM public.meta_estrelas m WHERE m.cod_rca::text = LTRIM(s.codusur, ''0'') AND m.filial::text = LTRIM(s.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_pos
            FROM target_sales s
            LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo
            GROUP BY dv.nome, s.filial, s.codusur
            ORDER BY COALESCE(SUM(CASE WHEN %s THEN s.peso ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN %s THEN s.peso ELSE 0 END), 0) DESC
        ),
        detalhes_json AS (
            SELECT COALESCE(json_agg(row_to_json(d)), ''[]''::json) as detalhes_array
            FROM detalhes_calc d
        )
        SELECT json_build_object(
            ''base_clientes'', COALESCE((SELECT total_clientes FROM base_clientes_cte), 0),
            ''sellout_salty'', COALESCE((SELECT salty_tonnage / 1000.0 FROM sales_data), 0),
            ''sellout_foods'', COALESCE((SELECT foods_tonnage / 1000.0 FROM sales_data), 0),
            ''positivacao_salty'', COALESCE((SELECT positivacao_salty FROM sales_data), 0),
            ''positivacao_foods'', COALESCE((SELECT positivacao_foods FROM sales_data), 0),
            ''aceleradores_realizado'', COALESCE((SELECT aceleradores_realizado FROM aceleradores_calc), 0),
            ''aceleradores_parcial'', COALESCE((SELECT aceleradores_parcial FROM aceleradores_calc), 0),
            ''aceleradores_qtd_marcas'', COALESCE((SELECT array_length(nomes, 1) FROM aceleradores_config), 0),
            ''sellout_salty_meta'', COALESCE((SELECT meta_salty FROM metas_calc), 0),
            ''sellout_foods_meta'', COALESCE((SELECT meta_foods FROM metas_calc), 0),
            ''positivacao_meta'', COALESCE((SELECT meta_pos FROM metas_calc), 0),
            ''aceleradores_meta'', CEIL(COALESCE((SELECT meta_pos FROM metas_calc), 0) * 0.5),
            ''detalhes'', COALESCE((SELECT detalhes_array FROM detalhes_json), ''[]''::json)
        )
    ', v_where_clients, v_where_base, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_current_year, v_eval_target_month, v_where_metas, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_current_year, v_eval_target_month, v_current_year, v_eval_target_month, v_current_year, v_eval_target_month, v_fornecedor_salty_cond, v_fornecedor_foods_cond);

    END;

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$$;

-- =========================================================================================
-- SUPERVISORS ROUTES TABLE
-- =========================================================================================
CREATE TABLE IF NOT EXISTS public.supervisors_routes (
    id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    cargo text,
    data_rota date,
    dia_semana text,
    supervisor text,
    rota_dia text,
    clientes_roteirizados integer,
    acompanhado_dia_codigo text,
    acompanhado_dia_nome text,
    foco_dia text,
    clientes_visitados integer,
    clientes_com_venda integer,
    observacao_rota text,
    eficiencia_visita text,
    eficiencia_rota text,
    eficiencia_saida text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT supervisors_routes_data_rota_supervisor_key UNIQUE (data_rota, supervisor)
);

ALTER TABLE public.supervisors_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.supervisors_routes
    FOR SELECT USING (true);

CREATE POLICY "Enable update/insert for authenticated users" ON public.supervisors_routes
    FOR ALL USING (auth.role() = 'authenticated');
