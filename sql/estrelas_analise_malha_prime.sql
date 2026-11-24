-- Malha Primes.xlsx, vigência a partir de 2025-10. Recorte da malha atual.
CREATE TABLE IF NOT EXISTS private.evolution_estrelas_malha (
  cidade text PRIMARY KEY,
  filial text NOT NULL CHECK (filial IN ('05','08'))
);
INSERT INTO private.evolution_estrelas_malha(cidade,filial) VALUES
('AIQUARA','08'),
('ALMADINA','05'),
('APUAREMA','05'),
('ARATACA','05'),
('AURELINO LEAL','05'),
('BARRA DO ROCHA','08'),
('BARRO PRETO','05'),
('BOA NOVA','08'),
('BOA VISTA DO TUPIM','08'),
('BREJOES','08'),
('BUERAREMA','05'),
('CAMACAN','05'),
('CANAVIEIRAS','05'),
('COARACI','05'),
('CRAVOLANDIA','08'),
('DARIO MEIRA','08'),
('FIRMINO ALVES','05'),
('FLORESTA AZUL','05'),
('GANDU','05'),
('GONGOGI','05'),
('IACU','08'),
('IBICARAI','05'),
('IBIQUERA','08'),
('IBIRAPITANGA','05'),
('IBIRATAIA','08'),
('ILHEUS','05'),
('IPIAU','08'),
('IRAJUBA','08'),
('IRAMAIA','08'),
('ITABERABA','08'),
('ITABUNA','05'),
('ITACARE','05'),
('ITAETE','08'),
('ITAGI','08'),
('ITAGIBA','08'),
('ITAJU DO COLONIA','05'),
('ITAJUIPE','05'),
('ITAMARI','05'),
('ITAPE','05'),
('ITAPITANGA','05'),
('ITAQUARA','08'),
('ITIRUCU','08'),
('JAGUAQUARA','08'),
('JEQUIE','08'),
('JIQUIRICA','08'),
('JITAUNA','08'),
('JUSSARI','05'),
('LAFAIETE COUTINHO','08'),
('LAJEDINHO','08'),
('LAJEDO DO TABOCAL','08'),
('MACAJUBA','08'),
('MANOEL VITORINO','08'),
('MARACAS','08'),
('MARCIONILIO SOUZA','08'),
('MASCOTE','05'),
('MILAGRES','08'),
('MUTUIPE','08'),
('NOVA IBIA','05'),
('NOVA ITARANA','08'),
('PAU BRASIL','05'),
('PIRAI DO NORTE','05'),
('PLANALTINO','08'),
('PRESIDENTE TANCREDO NEVES','05'),
('RUY BARBOSA','08'),
('SANTA CRUZ DA VITORIA','05'),
('SANTA INES','08'),
('SANTA LUZIA','05'),
('SAO JOSE DA VITORIA','05'),
('TEOLANDIA','05'),
('UBAIRA','08'),
('UBAITABA','05'),
('UBATA','05'),
('UNA','05'),
('URUCUCA','05'),
('UTINGA','08'),
('WAGNER','08'),
('WENCESLAU GUIMARAES','05')
ON CONFLICT (cidade) DO UPDATE SET filial=EXCLUDED.filial;
CREATE OR REPLACE FUNCTION private.evolution_malha_city(city text)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path TO pg_catalog AS $city$
  SELECT trim(regexp_replace(translate(upper(city),'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','AAAAAEEEEIIIIOOOOOUUUUC'),'[^A-Z0-9]+',' ','g'));
$city$;
CREATE OR REPLACE FUNCTION public.get_estrelas_malha_kpis_data(p_filial text[] DEFAULT NULL::text[], p_cidade text[] DEFAULT NULL::text[], p_supervisor text[] DEFAULT NULL::text[], p_vendedor text[] DEFAULT NULL::text[], p_fornecedor text[] DEFAULT NULL::text[], p_ano text DEFAULT NULL::text, p_mes text DEFAULT NULL::text, p_tipovenda text[] DEFAULT NULL::text[], p_rede text[] DEFAULT NULL::text[], p_categoria text[] DEFAULT NULL::text[])
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_current_year int;
    v_target_month int;
    v_eval_target_month int;

    v_where_base text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE 1=1 ';
    v_where_acel text := '';

    v_result json;
    v_sql text;

    v_fornecedor_salty_cond text := 's.codfor IN (''707'', ''708'', ''752'')';
    v_fornecedor_foods_cond text := 's.codfor IN (''1119'', ''1119_TODDY'', ''1119_TODDYNHO'', ''1119_QUAKER'', ''1119_KEROCOCO'', ''1119_OUTROS'')';
    v_code text;
    v_salty_codes text[] := '{}';
    v_foods_conds text[] := '{}';
BEGIN
    PERFORM private.evolution_assert_approved();
    SET LOCAL work_mem = '90MB';

    -- 1. Date Resolution
    IF p_ano IS NULL OR p_ano = 'todos' THEN
        v_current_year := (SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) FROM public.data_summary_frequency_current);
    ELSE
        v_current_year := p_ano::int;
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int;
        v_where_base := v_where_base || format(' AND s.ano = %L AND s.mes = %L ', v_current_year, v_target_month);
    ELSE
        v_where_base := v_where_base || format(' AND s.ano = %L ', v_current_year);
    END IF;

    v_eval_target_month := COALESCE(v_target_month, (SELECT COALESCE(MAX(mes), EXTRACT(MONTH FROM CURRENT_DATE)::int) FROM public.data_summary_frequency_current WHERE ano = v_current_year));

    -- 2. Build Where Clauses
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        IF NOT ('ambas' = ANY(p_filial)) THEN
            v_where_base := v_where_base || format(' AND s.filial = ANY(%L::text[]) ', p_filial);
            v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM private.evolution_estrelas_malha m WHERE m.cidade = private.evolution_malha_city(dc.cidade) AND m.filial = ANY(%L::text[])) ', p_filial);
        END IF;
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.cidade = ANY(%L::text[]) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND dc.cidade = ANY(%L::text[]) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])) ', p_supervisor);
        v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM public.data_summary_frequency_current sf WHERE sf.codcli = dc.codigo_cliente AND sf.codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[]))) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[])) ', p_vendedor);
        -- Client filtering logic simplified for exact matching where possible
        v_where_clients := v_where_clients || format(' AND EXISTS (SELECT 1 FROM public.data_summary_frequency_current sf WHERE sf.codcli = dc.codigo_cliente AND sf.codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L::text[]))) ', p_vendedor);
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

        IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                    IF LTRIM(v_code::text, '0') IN ('707', '708', '752') THEN
                        v_salty_codes := array_append(v_salty_codes, v_code);
                    ELSIF v_code = '1119' THEN
                        v_foods_conds := array_append(v_foods_conds, v_fornecedor_foods_cond);
                    ELSIF v_code IN ('1119_TODDY', '1119_TODDYNHO', '1119_QUAKER', '1119_KEROCOCO') THEN
                        v_foods_conds := array_append(v_foods_conds, format(
                            '(s.codfor = %L OR (s.codfor = ''1119'' AND s.categorias ? %L))',
                            v_code, substring(v_code from 6)));
                    ELSIF v_code = '1119_QUAKER_KEROCOCO' THEN
                        v_foods_conds := array_append(v_foods_conds, '(s.codfor IN (''1119_QUAKER'', ''1119_KEROCOCO'') OR (s.codfor = ''1119'' AND s.categorias ?| ARRAY[''QUAKER'', ''KEROCOCO'']))');
                    ELSIF v_code = '1119_OUTROS' THEN
                        v_foods_conds := array_append(v_foods_conds, '(s.codfor = ''1119_OUTROS'' OR (s.codfor = ''1119'' AND NOT COALESCE(s.categorias ?| ARRAY[''TODDY'', ''TODDYNHO'', ''QUAKER'', ''KEROCOCO''], false)))');
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
        END IF;

    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND s.categorias ?| %L::text[] ', p_categoria);
    END IF;

    -- Scope both the sale and its registered customer to the official network.
    v_where_base := v_where_base || ' AND EXISTS (SELECT 1 FROM private.evolution_estrelas_malha m
        WHERE m.filial = lpad(trim(s.filial), 2, ''0'')
          AND m.cidade = private.evolution_malha_city(s.cidade)
          AND m.cidade = private.evolution_malha_city(c.cidade))';
    v_where_clients := v_where_clients || ' AND EXISTS (SELECT 1 FROM private.evolution_estrelas_malha m
        WHERE m.cidade = private.evolution_malha_city(dc.cidade))';

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
                -- Optimization: Replaced heavy ROW_NUMBER() over raw data with DISTINCT on indexed summary table
                -- Expected Impact: ~6600ms -> ~170ms (38x faster).
                -- ⚡ [QueryTuner] Further Optimized: Replaced unrestricted subquery with direct IN clause.
                -- Expected Impact: ~56ms -> ~0.17ms (330x faster) by utilizing index scan directly.
                SELECT DISTINCT LTRIM(codusur, ''0'')
                FROM public.data_summary_frequency_current
                WHERE codsupervisor IN (
                    SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L::text[])
                )
            ) ', p_supervisor);
        END IF;

        v_sql := format('

        WITH scoped_clients AS MATERIALIZED (
            SELECT DISTINCT dc.codigo_cliente, ltrim(btrim(dc.rca1::text), ''0'') AS rca,
                private.evolution_malha_city(dc.cidade) AS cidade
            FROM public.data_clients dc
            %s
        ),
        base_clientes_cte AS (
            SELECT COUNT(DISTINCT codigo_cliente) as total_clientes FROM scoped_clients
        ),
        city_branches AS (
            SELECT cidade, filial FROM private.evolution_estrelas_malha
            UNION ALL
            SELECT DISTINCT private.evolution_malha_city(b.cidade), lpad(btrim(b.filial::text), 2, ''0'')
            FROM public.config_city_branches b
            WHERE NOT EXISTS (SELECT 1 FROM private.evolution_estrelas_malha m WHERE m.cidade=private.evolution_malha_city(b.cidade))
        ),
        portfolio AS (
            SELECT ltrim(btrim(dc.rca1::text), ''0'') AS rca, b.filial,
                count(DISTINCT dc.codigo_cliente) AS total,
                count(DISTINCT sc.codigo_cliente) AS inside
            FROM public.data_clients dc
            JOIN city_branches b ON b.cidade=private.evolution_malha_city(dc.cidade)
            LEFT JOIN scoped_clients sc ON sc.codigo_cliente=dc.codigo_cliente AND sc.cidade=b.cidade
            GROUP BY 1,2
        ),
        scoped_targets AS MATERIALIZED (
            SELECT m.ano,m.mes,m.filial,m.cod_rca,
                m.calibracao_salty::numeric * p.inside / p.total AS calibracao_salty,
                m.calibracao_foods::numeric * p.inside / p.total AS calibracao_foods,
                round(m.calibracao_pos::numeric * p.inside / p.total) AS calibracao_pos
            FROM public.meta_estrelas m
            JOIN portfolio p ON p.rca=m.cod_rca::text AND p.filial=lpad(m.filial::text,2,''0'')
            WHERE p.inside>0
        ),
        target_sales AS (
            SELECT s.*
            FROM public.data_summary_frequency_current s
            LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
            %s
        ),
        sales_data AS (
            SELECT
                SUM(t.total_tonnage) as total_tonnage,
                SUM(t.salty_tonnage) as salty_tonnage,
                SUM(t.foods_tonnage) as foods_tonnage,
                COUNT(DISTINCT CASE WHEN t.salty_venda >= 1 THEN t.codcli END) as positivacao_salty,
                COUNT(DISTINCT CASE WHEN t.foods_venda >= 1 AND (t.total_venda - t.foods_venda) < 1 THEN t.codcli END) as positivacao_foods
            FROM (
                SELECT 
                    s.codcli,
                    SUM(s.peso) as total_tonnage,
                    SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as salty_tonnage,
                    SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as foods_tonnage,
                    SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as salty_venda,
                    SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as foods_venda,
                    SUM(s.vlvenda) as total_venda
                FROM target_sales s
                GROUP BY s.codcli
            ) t
        ),
        aceleradores_config AS (
            SELECT array_agg(nome_categoria) as nomes FROM public.config_aceleradores
        ),
        aceleradores_calc AS (
            SELECT
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND s.categorias ?& (SELECT nomes FROM aceleradores_config) THEN s.codcli END) as aceleradores_realizado,
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND s.categorias ?| (SELECT nomes FROM aceleradores_config) AND NOT (s.categorias ?& (SELECT nomes FROM aceleradores_config)) THEN s.codcli END) as aceleradores_parcial
            FROM target_sales s
        ),
        metas_calc AS (
            SELECT
                COALESCE(SUM(calibracao_salty), 0) as meta_salty,
                COALESCE(SUM(calibracao_foods), 0) as meta_foods,
                COALESCE(SUM(calibracao_pos), 0) as meta_pos
            FROM scoped_targets m
            WHERE m.ano = %s AND m.mes = %s
            %s
        ),
        detalhes_calc AS (
            SELECT
                t.vendedor_nome,
                t.filial,
                COALESCE(SUM(t.salty_tonnage), 0) AS sellout_salty,
                COALESCE(SUM(t.foods_tonnage), 0) AS sellout_foods,
                COUNT(DISTINCT CASE WHEN t.salty_venda >= 1 THEN t.codcli END) AS pos_salty,
                COUNT(DISTINCT CASE WHEN t.foods_venda >= 1 AND (t.total_venda - t.foods_venda) < 1 THEN t.codcli END) AS pos_foods,
                (SELECT COUNT(DISTINCT CASE WHEN s2.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND s2.categorias ?& (SELECT nomes FROM aceleradores_config) THEN s2.codcli END) FROM target_sales s2 WHERE s2.codusur = t.codusur) AS acel_realizado,
                COALESCE((SELECT SUM(m.calibracao_salty) FROM scoped_targets m WHERE m.cod_rca::text = LTRIM(t.codusur, ''0'') AND m.filial::text = LTRIM(t.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_salty,
                COALESCE((SELECT SUM(m.calibracao_foods) FROM scoped_targets m WHERE m.cod_rca::text = LTRIM(t.codusur, ''0'') AND m.filial::text = LTRIM(t.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_foods,
                COALESCE((SELECT SUM(m.calibracao_pos) FROM scoped_targets m WHERE m.cod_rca::text = LTRIM(t.codusur, ''0'') AND m.filial::text = LTRIM(t.filial, ''0'') AND m.ano = %s AND m.mes = %s), 0) AS meta_pos
            FROM (
                SELECT 
                    COALESCE(dv.nome, ''N/D'') AS vendedor_nome,
                    s.filial,
                    s.codusur,
                    s.codcli,
                    SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as salty_tonnage,
                    SUM(CASE WHEN %s THEN s.peso ELSE 0 END) as foods_tonnage,
                    SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as salty_venda,
                    SUM(CASE WHEN %s THEN s.vlvenda ELSE 0 END) as foods_venda,
                    SUM(s.vlvenda) as total_venda
                FROM target_sales s
                LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo
                GROUP BY dv.nome, s.filial, s.codusur, s.codcli
            ) t
            GROUP BY t.vendedor_nome, t.filial, t.codusur
            ORDER BY COALESCE(SUM(t.salty_tonnage), 0) + COALESCE(SUM(t.foods_tonnage), 0) DESC
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
    ', v_where_clients, v_where_base, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_current_year, v_eval_target_month, v_where_metas, v_current_year, v_eval_target_month, v_current_year, v_eval_target_month, v_current_year, v_eval_target_month, v_fornecedor_salty_cond, v_fornecedor_foods_cond, v_fornecedor_salty_cond, v_fornecedor_foods_cond);

    END;

    EXECUTE v_sql INTO v_result;

    RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_estrelas_malha_kpis_data(text[],text[],text[],text[],text[],text,text,text[],text[],text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_estrelas_malha_kpis_data(text[],text[],text[],text[],text[],text,text,text[],text[],text[]) TO authenticated, service_role;
