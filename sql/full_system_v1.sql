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

-- ==============================================================================
-- MIGRATION: OPTIMIZATION OF FREQUENCY AND MIX TABLES
-- ==============================================================================

-- 1. Modify data_summary_frequency schema to include native arrays and pre-calculated mix flags
ALTER TABLE public.data_summary_frequency
    ADD COLUMN IF NOT EXISTS produtos_arr text[] null,
    ADD COLUMN IF NOT EXISTS categorias_arr text[] null,
    ADD COLUMN IF NOT EXISTS has_cheetos integer default null,
    ADD COLUMN IF NOT EXISTS has_doritos integer default null,
    ADD COLUMN IF NOT EXISTS has_fandangos integer default null,
    ADD COLUMN IF NOT EXISTS has_ruffles integer default null,
    ADD COLUMN IF NOT EXISTS has_torcida integer default null,
    ADD COLUMN IF NOT EXISTS has_toddynho integer default null,
    ADD COLUMN IF NOT EXISTS has_toddy integer default null,
    ADD COLUMN IF NOT EXISTS has_quaker integer default null,
    ADD COLUMN IF NOT EXISTS has_kerococo integer default null;

-- 2. Safely backfill array data
UPDATE public.data_summary_frequency f
SET
    produtos_arr = ARRAY(SELECT jsonb_array_elements_text(f.produtos)),
    categorias_arr = ARRAY(SELECT jsonb_array_elements_text(f.categorias))
WHERE f.produtos_arr IS NULL
  AND f.produtos IS NOT NULL
  AND jsonb_typeof(f.produtos) = 'array';

-- 3. Backfill mix flags using existing data
UPDATE public.data_summary_frequency s
SET
    has_cheetos = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'CHEETOS') THEN 1 ELSE NULL END,
    has_doritos = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'DORITOS') THEN 1 ELSE NULL END,
    has_fandangos = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'FANDANGOS') THEN 1 ELSE NULL END,
    has_ruffles = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'RUFFLES') THEN 1 ELSE NULL END,
    has_torcida = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'TORCIDA') THEN 1 ELSE NULL END,
    has_toddynho = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'TODDYNHO') THEN 1 ELSE NULL END,
    has_toddy = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'TODDY') THEN 1 ELSE NULL END,
    has_quaker = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'QUAKER') THEN 1 ELSE NULL END,
    has_kerococo = CASE WHEN EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = ANY(s.produtos_arr) AND dp.mix_marca = 'KEROCOCO') THEN 1 ELSE NULL END
WHERE s.produtos_arr IS NOT NULL;


-- Set existing 0 to NULL
UPDATE public.data_summary_frequency
SET
    has_cheetos = NULLIF(has_cheetos, 0),
    has_doritos = NULLIF(has_doritos, 0),
    has_fandangos = NULLIF(has_fandangos, 0),
    has_ruffles = NULLIF(has_ruffles, 0),
    has_torcida = NULLIF(has_torcida, 0),
    has_toddynho = NULLIF(has_toddynho, 0),
    has_toddy = NULLIF(has_toddy, 0),
    has_quaker = NULLIF(has_quaker, 0),
    has_kerococo = NULLIF(has_kerococo, 0);

-- 4. Create composite indexes for array intersection and optimized filtering
CREATE INDEX IF NOT EXISTS idx_freq_opt_produtos_arr ON public.data_summary_frequency USING GIN (produtos_arr);
CREATE INDEX IF NOT EXISTS idx_freq_opt_categorias_arr ON public.data_summary_frequency USING GIN (categorias_arr);
CREATE INDEX IF NOT EXISTS idx_freq_opt_mix_flags ON public.data_summary_frequency (has_cheetos, has_doritos, has_fandangos, has_ruffles, has_torcida, has_toddynho, has_toddy, has_quaker, has_kerococo);


-- 5. Update functions to use new structure
CREATE OR REPLACE FUNCTION get_mix_salty_foods_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
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
    v_where_chart text := ' WHERE 1=1 ';

    v_result json;
    v_sql text;

BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary_frequency);
    ELSE
        v_current_year := p_ano::int;
    END IF;

    v_where_chart := v_where_chart || ' AND s.ano = ' || v_current_year || ' ';

    -- 2. Build Where Clauses (Using data_summary_frequency columns directly)
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_chart := v_where_chart || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            DECLARE
                v_code text;
                v_conditions text[] := '{}';
                v_simple_codes text[] := '{}';
                v_cond_str text;
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDYNHO''])');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDY''])');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''QUAKER''])');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''KEROCOCO''])');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias_arr && ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                    ELSE
                        v_simple_codes := array_append(v_simple_codes, v_code);
                    END IF;
                END LOOP;

                IF array_length(v_simple_codes, 1) > 0 THEN
                    v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                END IF;

                IF array_length(v_conditions, 1) > 0 THEN
                    v_cond_str := array_to_string(v_conditions, ' OR ');
                    v_where_chart := v_where_chart || ' AND (' || v_cond_str || ') ';
                END IF;
            END;
        END IF;
    END IF;

    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF ('com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede)) AND ('sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede)) THEN
            -- Do nothing
        ELSIF 'com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede) THEN
            v_where_chart := v_where_chart || ' AND s.rede IS NOT NULL AND s.rede != '''' AND s.rede NOT IN (''N/A'', ''N/D'') ';
        ELSIF 'sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede) THEN
            v_where_chart := v_where_chart || ' AND (s.rede IS NULL OR s.rede = '''' OR s.rede IN (''N/A'', ''N/D'')) ';
        ELSE
            v_where_chart := v_where_chart || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_chart := v_where_chart || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    -- Dynamic Query hitting data_summary_frequency
    v_sql := '
    WITH monthly_mix AS (
        SELECT
            mes,
            codcli,
            MAX(has_cheetos) as has_cheetos,
            MAX(has_doritos) as has_doritos,
            MAX(has_fandangos) as has_fandangos,
            MAX(has_ruffles) as has_ruffles,
            MAX(has_torcida) as has_torcida,
            MAX(has_toddynho) as has_toddynho,
            MAX(has_toddy) as has_toddy,
            MAX(has_quaker) as has_quaker,
            MAX(has_kerococo) as has_kerococo
        FROM public.data_summary_frequency s
        ' || v_where_chart || ' AND s.tipovenda NOT IN (''5'', ''11'')
        GROUP BY 1, 2
    ),
    monthly_flags AS (
        SELECT
            mes,
            codcli,
            (COALESCE(has_cheetos,0)=1 AND COALESCE(has_doritos,0)=1 AND COALESCE(has_fandangos,0)=1 AND COALESCE(has_ruffles,0)=1 AND COALESCE(has_torcida,0)=1) as is_salty,
            (COALESCE(has_toddynho,0)=1 AND COALESCE(has_toddy,0)=1 AND COALESCE(has_quaker,0)=1 AND COALESCE(has_kerococo,0)=1) as is_foods
        FROM monthly_mix
    ),
    chart_data AS (
        SELECT
            ' || v_current_year || ' as ano,
            mes,
            COUNT(DISTINCT CASE WHEN is_salty THEN codcli END) as total_salty,
            COUNT(DISTINCT CASE WHEN is_foods THEN codcli END) as total_foods,
            COUNT(DISTINCT CASE WHEN is_salty AND is_foods THEN codcli END) as total_ambas
        FROM monthly_flags
        GROUP BY mes
        ORDER BY mes
    )
    SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data;
    ';

    EXECUTE v_sql INTO v_result;

    RETURN json_build_object(
        'chart_data', v_result,
        'current_year', v_current_year
    );
END;
$$;


CREATE OR REPLACE FUNCTION get_frequency_table_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null,
    p_categoria text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_eval_target_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_unnested text := ' ';
    v_where_base_prev text := ' WHERE 1=1 ';
    v_where_chart text := ' WHERE 1=1 ';
    v_pre_agg_skus_sql text;

    v_result json;
    v_sql text;
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '600s';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary_frequency);
    ELSE
        v_current_year := p_ano::int;
    END IF;

    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' AND s.mes = ' || v_target_month || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' AND s.mes = ' || v_target_month || ' ';
    ELSE
        v_where_base := v_where_base || ' AND s.ano = ' || v_current_year || ' ';
        v_where_base_prev := v_where_base_prev || ' AND s.ano = ' || v_previous_year || ' ';
    END IF;

    v_where_chart := v_where_chart || ' AND ano IN (' || v_previous_year || ', ' || v_current_year || ') ';

    -- 2. Build Where Clauses
    -- We apply regional filters (filial, cidade, vendedor) directly to v_where_base, v_where_base_prev, and v_where_clients
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_chart := v_where_chart || ' AND filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_clients := v_where_clients || ' AND cidade IN (SELECT cidade FROM public.config_city_branches WHERE filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || '''])) ';
            v_where_base := v_where_base || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.filial = ANY(ARRAY[''' || array_to_string(p_filial, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dc.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base := v_where_base || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.cidade = ANY(ARRAY[''' || array_to_string(p_cidade, ''',''') || ''']) ';
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND EXISTS (SELECT 1 FROM public.data_summary_frequency sf WHERE sf.codcli = dc.codigo_cliente AND sf.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || ''']))) ';
        v_where_chart := v_where_chart || ' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base := v_where_base || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(ARRAY[''' || array_to_string(p_supervisor, ''',''') || '''])) ';
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_clients := v_where_clients || ' AND dv.nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base := v_where_base || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
        v_where_base_prev := v_where_base_prev || ' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(ARRAY[''' || array_to_string(p_vendedor, ''',''') || '''])) ';
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_fornecedor)) THEN
            DECLARE
                v_code text;
                v_conditions text[] := '{}';
                v_unnested_conditions text[] := '{}';
                v_simple_codes text[] := '{}';
                v_cond_str text;
                v_unnested_str text;
            BEGIN
                FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF v_code = '1119_TODDYNHO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDYNHO''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''TODDYNHO'')');
                    ELSIF v_code = '1119_TODDY' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''TODDY''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''TODDY'')');
                    ELSIF v_code = '1119_QUAKER' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''QUAKER''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''QUAKER'')');
                    ELSIF v_code = '1119_KEROCOCO' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND s.categorias_arr && ARRAY[''KEROCOCO''])');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto = ''KEROCOCO'')');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND NOT (s.categorias_arr && ARRAY[''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO'']))');
                        v_unnested_conditions := array_append(v_unnested_conditions, '(dp.codfor = ''1119'' AND dp.categoria_produto NOT IN (''TODDYNHO'', ''TODDY'', ''QUAKER'', ''KEROCOCO''))');
                    ELSE
                        v_simple_codes := array_append(v_simple_codes, v_code);
                    END IF;
                END LOOP;

                IF array_length(v_simple_codes, 1) > 0 THEN
                    v_conditions := array_append(v_conditions, format('s.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                    v_unnested_conditions := array_append(v_unnested_conditions, format('dp.codfor = ANY(ARRAY[''%s''])', array_to_string(v_simple_codes, ''',''')));
                END IF;

                IF array_length(v_conditions, 1) > 0 THEN
                    v_cond_str := array_to_string(v_conditions, ' OR ');
                    v_unnested_str := array_to_string(v_unnested_conditions, ' OR ');

                    v_where_base := v_where_base || ' AND (' || v_cond_str || ') ';
                    v_where_base_prev := v_where_base_prev || ' AND (' || v_cond_str || ') ';
                    -- for chart alias 'codfor' is actually 's.codfor' in the view so we just string replace 's.' with '' for v_where_chart if necessary, but actually current_data in get_frequency_table_data has no alias prefix in monthly_freq, so let's use the CTE column name which is 'codfor' and 'categorias'
                    v_where_chart := v_where_chart || ' AND (' || replace(v_cond_str, 's.', '') || ') ';

                    IF v_unnested_str <> '' THEN
                        v_where_unnested := v_where_unnested || ' AND (' || v_unnested_str || ') ';
                    END IF;
                END IF;
            END;
        END IF;
    END IF;

    -- Redes Filtering Logic matching Innovations
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        IF ('com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede)) AND ('sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede)) THEN
            -- Do nothing, both selected essentially means all
        ELSIF 'com_ramo' = ANY(p_rede) OR 'C/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND dc.ramo IS NOT NULL AND dc.ramo != '''' ';
            v_where_chart := v_where_chart || ' AND rede IS NOT NULL AND rede != '''' ';
            v_where_base := v_where_base || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede IS NOT NULL AND s.rede != '''' ';
        ELSIF 'sem_ramo' = ANY(p_rede) OR 'S/ REDE' = ANY(p_rede) THEN
            v_where_clients := v_where_clients || ' AND (dc.ramo IS NULL OR dc.ramo = '''') ';
            v_where_chart := v_where_chart || ' AND (rede IS NULL OR rede = '''') ';
            v_where_base := v_where_base || ' AND (s.rede IS NULL OR s.rede = '''') ';
            v_where_base_prev := v_where_base_prev || ' AND (s.rede IS NULL OR s.rede = '''') ';
        ELSE
            -- Treat as explicit array values if not our magic tags
            v_where_clients := v_where_clients || ' AND dc.ramo = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_chart := v_where_chart || ' AND rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base := v_where_base || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
            v_where_base_prev := v_where_base_prev || ' AND s.rede = ANY(ARRAY[''' || array_to_string(p_rede, ''',''') || ''']) ';
        END IF;
    END IF;

    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND produtos_arr && ARRAY[''' || array_to_string(p_produto, ''',''') || '''] ';
        v_where_unnested := v_where_unnested || ' AND dp.descricao = ANY(ARRAY[''' || array_to_string(p_produto, ''',''') || ''']) ';
    END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_base_prev := v_where_base_prev || ' AND s.categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_chart := v_where_chart || ' AND categorias_arr && ARRAY[''' || array_to_string(p_categoria, ''',''') || '''] ';
        v_where_unnested := v_where_unnested || ' AND dp.categoria_produto = ANY(ARRAY[''' || array_to_string(p_categoria, ''',''') || ''']) ';
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_base_prev := v_where_base_prev || ' AND s.tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
        v_where_chart := v_where_chart || ' AND tipovenda = ANY(ARRAY[''' || array_to_string(p_tipovenda, ''',''') || ''']) ';
    END IF;

    IF v_where_unnested = ' ' OR v_where_unnested = '' THEN
        v_pre_agg_skus_sql := '
        SELECT
            c.filial, c.cidade, c.codusur, c.codcli,
            COUNT(DISTINCT p.produto) as dist_skus_per_cli
        FROM current_data c
        CROSS JOIN LATERAL unnest(c.produtos_arr) AS p(produto)
        WHERE c.tipovenda NOT IN (''5'', ''11'') AND c.vlvenda >= 1
        GROUP BY c.filial, c.cidade, c.codusur, c.codcli
        ';
    ELSE
        v_pre_agg_skus_sql := '
        SELECT
            c.filial, c.cidade, c.codusur, c.codcli,
            COUNT(DISTINCT dp.codigo) as dist_skus_per_cli
        FROM current_data c
        CROSS JOIN LATERAL unnest(c.produtos_arr) AS p(produto)
        INNER JOIN public.dim_produtos dp ON dp.codigo = p.produto
        WHERE c.tipovenda NOT IN (''5'', ''11'') AND c.vlvenda >= 1
        ' || v_where_unnested || '
        GROUP BY c.filial, c.cidade, c.codusur, c.codcli
        ';
    END IF;

    -- Dynamic Query
    v_sql := '

    WITH base_clients AS (
        SELECT
            dc.codigo_cliente as codcli,
            COALESCE(cb.filial, ''SEM FILIAL'') as filial,
            COALESCE(dc.cidade, ''SEM CIDADE'') as cidade,
            COALESCE(dv.nome, ''SEM VENDEDOR'') as vendedor
        FROM public.data_clients dc
        LEFT JOIN public.config_city_branches cb USING (cidade)
        LEFT JOIN public.dim_vendedores dv ON dc.rca1 = dv.codigo
        ' || v_where_clients || '
    ),
    current_data AS MATERIALIZED (
        SELECT
            s.filial,
            s.cidade,
            s.codusur,
            s.mes,
            s.codcli,
            s.pedido,
            s.tipovenda,
            s.vlvenda,
            s.peso,
            s.produtos,
            s.produtos_arr,
            s.categorias_arr
        FROM public.data_summary_frequency s
        ' || v_where_base || '
    ),
    previous_data AS (
        SELECT
            GROUPING(s.filial) as grp_filial,
            GROUPING(s.cidade) as grp_cidade,
            GROUPING(s.codusur) as grp_vendedor,
            COALESCE(s.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(s.cidade, ''TOTAL_CIDADE'') as cidade,
            s.codusur as vendedor_cod,
            SUM(s.vlvenda) as faturamento_prev
        FROM public.data_summary_frequency s
        ' || v_where_base_prev || ' AND s.tipovenda NOT IN (''5'', ''11'')
        GROUP BY ROLLUP(s.filial, s.cidade, s.codusur)
    ),
    client_base AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(vendedor) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            COALESCE(vendedor, ''TOTAL_VENDEDOR'') as vendedor,
            COUNT(DISTINCT codcli) as base_total
        FROM base_clients
        GROUP BY ROLLUP(filial, cidade, vendedor)
    ),
    pre_aggregated_skus AS (
        ' || v_pre_agg_skus_sql || '
    ),

    client_monthly_sales AS MATERIALIZED (
        SELECT
            c.filial, c.cidade, c.codusur, c.mes, c.codcli,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END)::numeric as month_pedidos,
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.vlvenda ELSE 0 END) as sum_vlvenda
        FROM current_data c
        GROUP BY c.filial, c.cidade, c.codusur, c.mes, c.codcli
    ),
    monthly_freq AS (
        SELECT
            filial,
            cidade,
            codusur,
            mes,
            SUM(month_pedidos) as month_pedidos,
            SUM(CASE WHEN sum_vlvenda >= 1 THEN 1 ELSE 0 END)::numeric as month_clientes
        FROM client_monthly_sales
        GROUP BY filial, cidade, codusur, mes
    ),

    rolled_monthly_freq AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            -- Calculate frequency per month, then average those frequencies across active months
            AVG(CASE WHEN month_clientes > 0 THEN month_pedidos / month_clientes ELSE NULL END) as avg_monthly_freq
        FROM monthly_freq
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),
    aggregated_curr AS (
        SELECT
            GROUPING(c.filial) as grp_filial,
            GROUPING(c.cidade) as grp_cidade,
            GROUPING(c.codusur) as grp_vendedor,
            COALESCE(c.filial, ''TOTAL_GERAL'') as filial,
            COALESCE(c.cidade, ''TOTAL_CIDADE'') as cidade,
            c.codusur as vendedor_cod,
            SUM(c.peso) as tons,
            SUM(CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.vlvenda ELSE 0 END) as faturamento,
            COUNT(DISTINCT CASE WHEN c.tipovenda NOT IN (''5'', ''11'') THEN c.pedido END) as total_pedidos,
            COUNT(DISTINCT c.mes) as q_meses
        FROM current_data c
        GROUP BY ROLLUP(c.filial, c.cidade, c.codusur)
    ),
    aggregated_positivados AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            COUNT(DISTINCT CASE WHEN sum_vlvenda >= 1 THEN codcli END) as positivacao,
            COUNT(DISTINCT CASE WHEN sum_vlvenda >= 1 THEN codcli::text || ''-'' || mes::text END) as positivacao_mensal
        FROM client_monthly_sales
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),

    aggregated_skus AS (
        SELECT
            GROUPING(filial) as grp_filial,
            GROUPING(cidade) as grp_cidade,
            GROUPING(codusur) as grp_vendedor,
            COALESCE(filial, ''TOTAL_GERAL'') as filial,
            COALESCE(cidade, ''TOTAL_CIDADE'') as cidade,
            codusur as vendedor_cod,
            SUM(dist_skus_per_cli) as sum_skus
        FROM pre_aggregated_skus
        GROUP BY ROLLUP(filial, cidade, codusur)
    ),
    final_tree AS (
        SELECT
            ac.grp_filial,
            ac.grp_cidade,
            ac.grp_vendedor,
            ac.filial,
            ac.cidade,
            COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1),
                CASE WHEN ac.grp_vendedor = 1 THEN ''TOTAL_VENDEDOR'' ELSE ''SEM VENDEDOR'' END
            ) as vendedor,
            ac.tons,
            ac.faturamento,
            COALESCE(pd.faturamento_prev, 0) as faturamento_prev,
            COALESCE(ap.positivacao, 0) as positivacao,
            COALESCE(ap.positivacao_mensal, 0) as positivacao_mensal,
            COALESCE(ask.sum_skus, 0)::numeric as sum_skus,
            ac.total_pedidos::numeric as total_pedidos,
            ac.q_meses,
            COALESCE(mf.avg_monthly_freq, 0) as avg_monthly_freq,
            COALESCE(cb.base_total, 0) as base_total
        FROM aggregated_curr ac
        LEFT JOIN aggregated_positivados ap
            ON ac.grp_filial = ap.grp_filial
            AND ac.grp_cidade = ap.grp_cidade
            AND ac.grp_vendedor = ap.grp_vendedor
            AND ac.filial = ap.filial
            AND ac.cidade = ap.cidade
            AND ac.vendedor_cod IS NOT DISTINCT FROM ap.vendedor_cod
        LEFT JOIN previous_data pd ON ac.grp_filial = pd.grp_filial
                                  AND ac.grp_cidade = pd.grp_cidade
                                  AND ac.grp_vendedor = pd.grp_vendedor
                                  AND ac.filial = pd.filial
                                  AND ac.cidade = pd.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM pd.vendedor_cod

        LEFT JOIN rolled_monthly_freq mf ON ac.grp_filial = mf.grp_filial
                                  AND ac.grp_cidade = mf.grp_cidade
                                  AND ac.grp_vendedor = mf.grp_vendedor
                                  AND ac.filial = mf.filial
                                  AND ac.cidade = mf.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM mf.vendedor_cod
        LEFT JOIN aggregated_skus ask ON ac.grp_filial = ask.grp_filial
                                  AND ac.grp_cidade = ask.grp_cidade
                                  AND ac.grp_vendedor = ask.grp_vendedor
                                  AND ac.filial = ask.filial
                                  AND ac.cidade = ask.cidade
                                  AND ac.vendedor_cod IS NOT DISTINCT FROM ask.vendedor_cod
        LEFT JOIN client_base cb ON ac.grp_filial = cb.grp_filial
                                AND ac.grp_cidade = cb.grp_cidade
                                AND ac.grp_vendedor = cb.grp_vendedor
                                AND ac.filial = cb.filial
                                AND ac.cidade = cb.cidade
                                AND COALESCE((SELECT nome FROM public.dim_vendedores WHERE codigo = ac.vendedor_cod LIMIT 1),
                                    CASE WHEN ac.grp_vendedor = 1 THEN ''TOTAL_VENDEDOR'' ELSE ''SEM VENDEDOR'' END) = cb.vendedor
    ),
    chart_monthly_sales AS (
        SELECT s.ano, s.mes, s.codcli,
               COUNT(DISTINCT CASE WHEN s.tipovenda NOT IN (''5'', ''11'') THEN s.pedido END) as month_pedidos,
               SUM(CASE WHEN s.tipovenda NOT IN (''5'', ''11'') THEN s.vlvenda ELSE 0 END) as sum_vlvenda
        FROM public.data_summary_frequency s
        ' || v_where_chart || '
        GROUP BY s.ano, s.mes, s.codcli
    ),
    chart_data AS (
        SELECT
            ano,
            mes,
            SUM(month_pedidos) as total_pedidos,
            SUM(CASE WHEN sum_vlvenda >= 1 THEN 1 ELSE 0 END) as total_clientes
        FROM chart_monthly_sales
        GROUP BY 1, 2
    )
    SELECT json_build_object(
        ''tree_data'', (SELECT COALESCE(json_agg(row_to_json(final_tree)), ''[]''::json) FROM final_tree),
        ''chart_data'', (SELECT COALESCE(json_agg(row_to_json(chart_data)), ''[]''::json) FROM chart_data),
        ''current_year'', ' || v_current_year || ',
        ''previous_year'', ' || v_previous_year || ',
        ''global_base_total'', (SELECT COUNT(DISTINCT codcli) FROM base_clients)
    );
    ';

    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;

-- ==========================================
-- SUPERVISORS ROUTES (GOOGLE SHEETS INTEGRATION)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.supervisors_routes (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    cargo TEXT,
    data_rota DATE,
    dia_semana TEXT,
    supervisor TEXT,
    rota_dia TEXT,
    clientes_roteirizados INTEGER,
    acompanhado_dia_codigo TEXT,
    acompanhado_dia_nome text,
    foco_dia TEXT,
    clientes_visitados INTEGER,
    clientes_com_venda INTEGER,
    observacao_rota TEXT,
    eficiencia_visita TEXT,
    eficiencia_rota TEXT,
    eficiencia_saida TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT supervisors_routes_data_rota_supervisor_key UNIQUE(data_rota, supervisor)
);
ALTER TABLE public.supervisors_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all users" ON public.supervisors_routes
    FOR SELECT USING (true);

CREATE POLICY "Enable update/insert for authenticated users" ON public.supervisors_routes
    FOR ALL USING (auth.role() = 'authenticated');
