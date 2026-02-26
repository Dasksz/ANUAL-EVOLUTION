-- ==============================================================================
-- MIGRATION V2: CATEGORIES (BRANDS) & FILTER
-- Adds robust categorization logic and enables filtering by category in dashboards.
-- ==============================================================================

-- 1. Schema Updates
-- ------------------------------------------------------------------------------

-- Add Category Column to Dimensions
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'categoria_produto') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN categoria_produto text;
    END IF;
END $$;

-- Add Category Column to Summary (Dimension)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_summary' AND column_name = 'categoria_produto') THEN
        ALTER TABLE public.data_summary ADD COLUMN categoria_produto text;
    END IF;
END $$;

-- Add Category Column to Cache Filters
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cache_filters' AND column_name = 'categoria_produto') THEN
        ALTER TABLE public.cache_filters ADD COLUMN categoria_produto text;
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dim_produtos_categoria ON public.dim_produtos (categoria_produto);
CREATE INDEX IF NOT EXISTS idx_summary_categoria ON public.data_summary (categoria_produto);
CREATE INDEX IF NOT EXISTS idx_cache_filters_categoria ON public.cache_filters (categoria_produto);

-- 2. Update Classification Logic
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION classify_product_mix()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Legacy Mix Logic (Keep for backward compatibility)
    NEW.mix_marca := NULL;
    NEW.mix_categoria := NULL;

    IF NEW.descricao ILIKE '%CHEETOS%' THEN NEW.mix_marca := 'CHEETOS';
    ELSIF NEW.descricao ILIKE '%DORITOS%' THEN NEW.mix_marca := 'DORITOS';
    ELSIF NEW.descricao ILIKE '%FANDANGOS%' THEN NEW.mix_marca := 'FANDANGOS';
    ELSIF NEW.descricao ILIKE '%RUFFLES%' THEN NEW.mix_marca := 'RUFFLES';
    ELSIF NEW.descricao ILIKE '%TORCIDA%' THEN NEW.mix_marca := 'TORCIDA';
    ELSIF NEW.descricao ILIKE '%TODDYNHO%' THEN NEW.mix_marca := 'TODDYNHO';
    ELSIF NEW.descricao ILIKE '%TODDY %' THEN NEW.mix_marca := 'TODDY';
    ELSIF NEW.descricao ILIKE '%QUAKER%' THEN NEW.mix_marca := 'QUAKER';
    ELSIF NEW.descricao ILIKE '%KEROCOCO%' THEN NEW.mix_marca := 'KEROCOCO';
    END IF;

    IF NEW.mix_marca IN ('CHEETOS', 'DORITOS', 'FANDANGOS', 'RUFFLES', 'TORCIDA') THEN
        NEW.mix_categoria := 'SALTY';
    ELSIF NEW.mix_marca IN ('TODDYNHO', 'TODDY', 'QUAKER', 'KEROCOCO') THEN
        NEW.mix_categoria := 'FOODS';
    END IF;

    -- 2. New Robust Category Logic (categoria_produto)
    NEW.categoria_produto := 'OUTROS'; -- Default

    -- Priority Matches (Specific Variations & Sub-brands)
    IF NEW.descricao ILIKE '%CHEETOS CRUNCHY%' THEN NEW.categoria_produto := 'CHEETOS CRUNCHY';
    ELSIF NEW.descricao ILIKE '%DORITOS DIN%' THEN NEW.categoria_produto := 'DORITOS DINAMITA';
    ELSIF NEW.descricao ILIKE '%LAYS RUSTICAS%' THEN NEW.categoria_produto := 'LAYS RUSTICA';
    ELSIF NEW.descricao ILIKE '%STAX%' THEN NEW.categoria_produto := 'STAX'; -- Check before LAYS
    ELSIF NEW.descricao ILIKE '%SENSACOES%' THEN NEW.categoria_produto := 'SENSACOES'; -- Check before LAYS

    -- General Matches
    ELSIF NEW.descricao ILIKE '%BACONZITOS%' THEN NEW.categoria_produto := 'BACONZITOS';
    ELSIF NEW.descricao ILIKE '%CEBOLITOS%' THEN NEW.categoria_produto := 'CEBOLITOS';
    ELSIF NEW.descricao ILIKE '%CHEETOS%' THEN NEW.categoria_produto := 'CHEETOS';
    ELSIF NEW.descricao ILIKE '%DORITOS%' THEN NEW.categoria_produto := 'DORITOS';
    ELSIF NEW.descricao ILIKE '%AMENDOIM%' THEN NEW.categoria_produto := 'ELMA-CHIPS AMENDOIM';
    ELSIF NEW.descricao ILIKE '%PALHA%' THEN NEW.categoria_produto := 'ELMA-CHIPS PALHA';
    ELSIF NEW.descricao ILIKE '%FANDANGOS%' THEN NEW.categoria_produto := 'FANDANGOS';
    ELSIF NEW.descricao ILIKE '%LANCHINHO%' THEN NEW.categoria_produto := 'LANCHINHO';
    ELSIF NEW.descricao ILIKE '%LAYS%' THEN NEW.categoria_produto := 'LAYS';
    ELSIF NEW.descricao ILIKE '%PINGO DOURO%' THEN NEW.categoria_produto := 'PINGO DOURO';
    ELSIF NEW.descricao ILIKE '%POPCORNERS%' THEN NEW.categoria_produto := 'POPCORNERS';
    ELSIF NEW.descricao ILIKE '%RUFFLES%' THEN NEW.categoria_produto := 'RUFFLES';
    ELSIF NEW.descricao ILIKE '%STIKSY%' THEN NEW.categoria_produto := 'STIKSY';
    ELSIF NEW.descricao ILIKE '%TOSTITOS%' THEN NEW.categoria_produto := 'TOSTITOS';
    ELSIF NEW.descricao ILIKE '%EQLIBRI%' THEN NEW.categoria_produto := 'EQLIBRI';
    ELSIF NEW.descricao ILIKE '%FOFURA%' THEN NEW.categoria_produto := 'FOFURA';
    ELSIF NEW.descricao ILIKE '%TORCIDA%' THEN NEW.categoria_produto := 'TORCIDA';

    -- Foods / Others (Mapped to same names as legacy mix but in new column)
    ELSIF NEW.descricao ILIKE '%TODDYNHO%' THEN NEW.categoria_produto := 'TODDYNHO';
    ELSIF NEW.descricao ILIKE '%TODDY %' THEN NEW.categoria_produto := 'TODDY';
    ELSIF NEW.descricao ILIKE '%QUAKER%' THEN NEW.categoria_produto := 'QUAKER';
    ELSIF NEW.descricao ILIKE '%KEROCOCO%' THEN NEW.categoria_produto := 'KEROCOCO';
    END IF;

    RETURN NEW;
END;
$$;

-- Apply to existing data
UPDATE public.dim_produtos SET descricao = descricao;

-- 3. Update Refresh Logic (Summary)
-- ------------------------------------------------------------------------------

-- Update Refresh Year to include categoria_produto
CREATE OR REPLACE FUNCTION refresh_summary_year(p_year int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    DELETE FROM public.data_summary WHERE ano = p_year;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_detailed
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_history
        WHERE EXTRACT(YEAR FROM dtped)::int = p_year
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda_embalagem_master,
            c.ramo,
            dp.categoria_produto -- Added
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda_embalagem_master, 0)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        total_caixas,
        categoria_produto
    FROM client_agg;

    ANALYZE public.data_summary;
END;
$$;

-- Update Refresh Month
CREATE OR REPLACE FUNCTION refresh_summary_month(p_year int, p_month int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Clear data for this year/month first (avoid duplicates)
    DELETE FROM public.data_summary WHERE ano = p_year AND mes = p_month;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas, categoria_produto
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_detailed
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_history
        WHERE dtped >= make_date(p_year, p_month, 1) AND dtped < (make_date(p_year, p_month, 1) + interval '1 month')
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            s.codsupervisor,
            s.codusur,
            CASE
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor
            END as codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto, s.qtvenda_embalagem_master,
            c.ramo,
            dp.categoria_produto -- Added
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, categoria_produto, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda_embalagem_master, 0)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo, pa.categoria_produto,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        total_caixas,
        categoria_produto
    FROM client_agg;
END;
$$;

-- 4. Update Filter Cache
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    ANALYZE public.data_summary;

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede, categoria_produto)
    SELECT DISTINCT
        t.filial,
        t.cidade,
        ds.nome as superv,
        dv.nome as nome,
        t.codfor,
        CASE
            WHEN t.codfor = '707' THEN 'EXTRUSADOS'
            WHEN t.codfor = '708' THEN 'Ñ EXTRUSADOS'
            WHEN t.codfor = '752' THEN 'TORCIDA'
            WHEN t.codfor = '1119_TODDYNHO' THEN 'TODDYNHO'
            WHEN t.codfor = '1119_TODDY' THEN 'TODDY'
            WHEN t.codfor = '1119_QUAKER' THEN 'QUAKER'
            WHEN t.codfor = '1119_KEROCOCO' THEN 'KEROCOCO'
            WHEN t.codfor = '1119_OUTROS' THEN 'FOODS (Outros)'
            WHEN t.codfor = '1119' THEN 'FOODS (Outros)'
            ELSE df.nome
        END as fornecedor,
        t.tipovenda,
        t.ano,
        t.mes,
        t.ramo as rede,
        t.categoria_produto
    FROM public.data_summary t
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codusur = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo;
END;
$$;

-- 5. Update Get Filters (Create if missing)
-- ------------------------------------------------------------------------------

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
    p_categoria text[] default null -- Added
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_where text := ' WHERE 1=1 ';
    v_result json;
BEGIN
    -- Construct Where Clause
    IF p_ano IS NOT NULL AND p_ano != 'todos' THEN
        v_where := v_where || format(' AND ano = %L ', p_ano::int);
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_where := v_where || format(' AND mes = %L ', p_mes::int + 1);
    END IF;
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        -- Basic filtering for dropdowns
        v_where := v_where || format(' AND rede = ANY(%L) ', p_rede);
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where := v_where || format(' AND categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- Execute with dynamic JSON construction
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
        ''categorias'', (SELECT array_agg(DISTINCT categoria_produto ORDER BY categoria_produto) FROM public.cache_filters ' || v_where || ' AND categoria_produto IS NOT NULL)
    )' INTO v_result;

    RETURN v_result;
END;
$$;

-- 6. Update Main Dashboard Data (Add Filter)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_main_dashboard_data(
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
    p_categoria text[] default null -- Added
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

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_work_days_passed int;
    v_work_days_total int;
    v_trend_factor numeric := 0;
    v_trend_data json;
    v_month_start date;
    v_month_end date;
    v_holidays json;

    -- Dynamic SQL
    v_sql text;
    v_where_base text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_result json;

    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_curr_month_idx int;

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
    v_is_month_filtered boolean := false;

    -- Mix Logic Vars
    v_mix_constraint text;

    -- New KPI Logic Vars
    v_filial_cities text[];
    v_supervisor_rcas text[];
    v_vendedor_rcas text[];
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '60s';

    -- 1. Determine Date Ranges
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_is_month_filtered := true;
    ELSE
         SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year;
         v_is_month_filtered := false;
    END IF;

    -- 2. Trend Logic Calculation
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN
           v_trend_allowed := false;
       END IF;
    END IF;

    IF v_trend_allowed THEN
        v_month_start := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
    END IF;

    -- 3. Construct Dynamic WHERE Clause

    v_where_base := v_where_base || format(' AND ano IN (%L, %L) ', v_current_year, v_previous_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_base := v_where_base || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_categoria IS NOT NULL AND array_length(p_categoria, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND categoria_produto = ANY(%L) ', p_categoria);
    END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('ramo = ANY(%L)', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NULL OR ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_base := v_where_base || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- MIX Constraint Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_mix_constraint := ' 1=1 ';
    ELSE
        v_mix_constraint := ' fs.codfor IN (''707'', ''708'') ';
    END IF;

    -- KPI Base Filter (Table: data_clients)
    -- NOTE: data_clients does not have 'categoria_produto'. Filtering base clients by product category is tricky.
    -- We usually filter base clients by attributes of the client (City, Supervisor).
    -- If 'Categoria' filter is ON, what happens to "Clientes na Base"?
    -- Usually "Base" implies all clients who COULD buy.
    -- Filtering by product sold implies filtering by sales.
    -- For now, I will NOT apply category filter to "Base Clients" query as it's not a client attribute.

    v_where_kpi := ' WHERE bloqueio != ''S'' ';
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    -- FILIAL LOGIC FOR KPI
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        SELECT array_agg(DISTINCT cidade) INTO v_filial_cities
        FROM public.config_city_branches
        WHERE filial = ANY(p_filial);

        IF v_filial_cities IS NOT NULL THEN
             v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', v_filial_cities);
        ELSE
             v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- SUPERVISOR LOGIC FOR KPI
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        SELECT array_agg(DISTINCT d.codusur) INTO v_supervisor_rcas
        FROM public.data_detailed d
        JOIN public.dim_supervisores ds ON d.codsupervisor = ds.codigo
        WHERE ds.nome = ANY(p_supervisor);

        IF v_supervisor_rcas IS NOT NULL THEN
            v_where_kpi := v_where_kpi || format(' AND rca1 = ANY(%L) ', v_supervisor_rcas);
        ELSE
             v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- VENDEDOR LOGIC FOR KPI
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        SELECT array_agg(DISTINCT codigo) INTO v_vendedor_rcas
        FROM public.dim_vendedores
        WHERE nome = ANY(p_vendedor);

        IF v_vendedor_rcas IS NOT NULL THEN
            v_where_kpi := v_where_kpi || format(' AND rca1 = ANY(%L) ', v_vendedor_rcas);
        ELSE
            v_where_kpi := v_where_kpi || ' AND 1=0 ';
        END IF;
    END IF;

    -- REDE KPI
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
        v_rede_condition := ''; -- reset
        IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('ramo = ANY(%L)', v_specific_redes);
        END IF;
        IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NOT NULL AND ramo NOT IN (''N/A'', ''N/D'')) ';
        END IF;
        IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (ramo IS NULL OR ramo IN (''N/A'', ''N/D'')) ';
        END IF;
        IF v_rede_condition != '' THEN
            v_where_kpi := v_where_kpi || ' AND (' || v_rede_condition || ') ';
        END IF;
    END IF;

    -- 4. Execute Main Aggregation Query
    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda, codfor, categoria_produto
        FROM public.data_summary
        ' || v_where_base || '
    ),
    monthly_client_agg AS (
        SELECT ano, mes, codcli
        FROM filtered_summary
        WHERE (
            CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1)
                ELSE tipovenda NOT IN (''5'', ''11'')
            END
        )
        GROUP BY ano, mes, codcli
        HAVING (
            ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
            OR
            ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
        )
    ),
    monthly_counts AS (
        SELECT ano, mes, COUNT(*) as active_count
        FROM monthly_client_agg
        GROUP BY ano, mes
    ),
    agg_data AS (
        SELECT
            fs.ano,
            fs.mes,
            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.vlvenda ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') THEN fs.vlvenda
                ELSE 0
            END) as faturamento,

            SUM(CASE
                WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.vlvenda
                ELSE 0
            END) as total_sold_base,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) THEN fs.peso ELSE 0 END
                ELSE
                    CASE
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                             CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso ELSE 0 END
                        WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso
                        ELSE 0
                    END
            END) as peso,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 && ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
                ELSE
                     CASE WHEN fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
            END) as bonificacao,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.devolucao ELSE 0 END
                ELSE fs.devolucao
            END) as devolucao,

            COALESCE(mc.active_count, 0) as positivacao_count,

            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.pre_mix_count ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') AND (' || v_mix_constraint || ') THEN fs.pre_mix_count
                ELSE 0
            END) as total_mix_sum,

            COUNT(DISTINCT CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) AND fs.pre_mix_count > 0 THEN
                    CASE WHEN fs.tipovenda = ANY($1) AND (' || v_mix_constraint || ') THEN fs.codcli ELSE NULL END
                WHEN fs.tipovenda IN (''1'', ''9'') AND fs.pre_mix_count > 0 AND (' || v_mix_constraint || ') THEN fs.codcli
                ELSE NULL
            END) as mix_client_count
        FROM filtered_summary fs
        LEFT JOIN monthly_counts mc ON fs.ano = mc.ano AND fs.mes = mc.mes
        GROUP BY fs.ano, fs.mes, mc.active_count
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
            SELECT codcli
            FROM filtered_summary
            WHERE ano = $2
            ' || CASE WHEN v_is_month_filtered THEN ' AND mes = $3 ' ELSE '' END || '
            AND (
                CASE
                    WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN tipovenda = ANY($1)
                    ELSE tipovenda NOT IN (''5'', ''11'')
                END
            )
            GROUP BY codcli
            HAVING (
                ( ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(bonificacao) > 0 )
                OR
                ( NOT ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) AND SUM(vlvenda) >= 1 )
            )
        ) t
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients
        ' || v_where_kpi || '
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $2), ''[]''::json),

        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1,
            ''faturamento'', a.faturamento,
            ''total_sold_base'', a.total_sold_base,
            ''peso'', a.peso,
            ''bonificacao'', a.bonificacao,
            ''devolucao'', a.devolucao,
            ''positivacao'', a.positivacao_count,
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END,
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $4), ''[]''::json)
    FROM agg_data a
    ';

    EXECUTE v_sql
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    USING p_tipovenda, v_current_year, v_target_month, v_previous_year;

    -- 5. Calculate Trend (Post-Processing)
    IF v_trend_allowed THEN
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;

        DECLARE
             v_elem json;
        BEGIN
            FOR v_elem IN SELECT * FROM json_array_elements(v_monthly_chart_current)
            LOOP
                IF (v_elem->>'month_index')::int = v_curr_month_idx THEN
                    v_trend_data := json_build_object(
                        'month_index', v_curr_month_idx,
                        'faturamento', (v_elem->>'faturamento')::numeric * v_trend_factor,
                        'peso', (v_elem->>'peso')::numeric * v_trend_factor,
                        'bonificacao', (v_elem->>'bonificacao')::numeric * v_trend_factor,
                        'devolucao', (v_elem->>'devolucao')::numeric * v_trend_factor,
                        'positivacao', ((v_elem->>'positivacao')::numeric * v_trend_factor)::int,
                        'mix_pdv', (v_elem->>'mix_pdv')::numeric,
                        'ticket_medio', (v_elem->>'ticket_medio')::numeric
                    );
                END IF;
            END LOOP;
        END;
    END IF;

    SELECT json_agg(date) INTO v_holidays FROM public.data_holidays;

    v_result := json_build_object(
        'current_year', v_current_year,
        'previous_year', v_previous_year,
        'target_month_index', v_target_month - 1,
        'kpi_clients_attended', COALESCE(v_kpi_clients_attended, 0),
        'kpi_clients_base', COALESCE(v_kpi_clients_base, 0),
        'monthly_data_current', v_monthly_chart_current,
        'monthly_data_previous', v_monthly_chart_previous,
        'trend_data', v_trend_data,
        'trend_allowed', v_trend_allowed,
        'holidays', COALESCE(v_holidays, '[]'::json)
    );
    RETURN v_result;
END;
$$;

-- 7. Backfill Data (Regenerate Summary with new Grain)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r_year int;
    r_month int;
BEGIN
    RAISE NOTICE 'Iniciando regeneração do Data Summary (Isso pode demorar)...';

    -- Clear old data (grain changed)
    TRUNCATE TABLE public.data_summary;

    -- Loop Years and Months
    FOR r_year IN SELECT DISTINCT EXTRACT(YEAR FROM dtped)::int FROM public.data_detailed
                  UNION
                  SELECT DISTINCT EXTRACT(YEAR FROM dtped)::int FROM public.data_history
    LOOP
        IF r_year IS NOT NULL THEN
            FOR r_month IN 1..12
            LOOP
                PERFORM refresh_summary_month(r_year, r_month);
            END LOOP;
        END IF;
    END LOOP;

    -- Refresh Filters
    PERFORM refresh_cache_filters();

    RAISE NOTICE 'Migração Concluída com Sucesso.';
END $$;
