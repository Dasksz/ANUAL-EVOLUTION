
-- ==============================================================================
-- FAST RESPONSE OPTIMIZATIONS
-- 1. Schema Definitions (Table & Indexes)
-- 2. Materialize Logic into Summary Table
-- 3. Dynamic SQL for Instant Reads
-- 4. Aggregated Branch RPC
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SCHEMA DEFINITIONS (DDL)
-- ------------------------------------------------------------------------------

-- Create Summary Table (if not exists)
CREATE TABLE IF NOT EXISTS public.data_summary (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    ano int,
    mes int,
    filial text,
    cidade text,
    superv text,
    nome text,
    codfor text,
    tipovenda text,
    codcli text,
    vlvenda numeric,
    peso numeric,
    bonificacao numeric,
    devolucao numeric,
    mix_produtos text[],
    mix_details jsonb, -- Stores product-level values for accurate Mix calculation
    pre_mix_count int DEFAULT 0,
    pre_positivacao_val int DEFAULT 0, -- 1 se positivou, 0 se não
    created_at timestamp with time zone default now()
);

-- Ensure RLS is enabled and policies exist (idempotent)
ALTER TABLE public.data_summary ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    -- Drop old policies to ensure clean state
    DROP POLICY IF EXISTS "Read Access Approved" ON public.data_summary;
    DROP POLICY IF EXISTS "Write Access Admin" ON public.data_summary;
    DROP POLICY IF EXISTS "Update Access Admin" ON public.data_summary;
    DROP POLICY IF EXISTS "Delete Access Admin" ON public.data_summary;

    -- Recreate Policies
    CREATE POLICY "Read Access Approved" ON public.data_summary FOR SELECT USING (public.is_approved());
    CREATE POLICY "Write Access Admin" ON public.data_summary FOR INSERT WITH CHECK (public.is_admin());
    CREATE POLICY "Update Access Admin" ON public.data_summary FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
    CREATE POLICY "Delete Access Admin" ON public.data_summary FOR DELETE USING (public.is_admin());
END $$;

-- Create Indexes for Dynamic SQL & Clustering
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_filial ON public.data_summary (ano, mes, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_cidade ON public.data_summary (ano, mes, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_superv ON public.data_summary (ano, mes, superv);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_nome ON public.data_summary (ano, mes, nome); -- Vendedor
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codfor ON public.data_summary (ano, mes, codfor);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_tipovenda ON public.data_summary (ano, mes, tipovenda);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codcli ON public.data_summary (ano, mes, codcli);


-- ------------------------------------------------------------------------------
-- 2. OPTIMIZED REFRESH SUMMARY (Bake Logic In)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;

    -- Inserção OTIMIZADA:
    -- 1. Aplica regra de filial (11625) na gravação
    -- 2. Já calcula se houve positivação e contagem de mix
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        mix_produtos, mix_details,
        pre_mix_count, pre_positivacao_val
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_history
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            -- LOGIC FIX: Override Branch for Client 11625 in Dec 2025
            CASE
                WHEN s.codcli = '11625' AND EXTRACT(YEAR FROM s.dtped) = 2025 AND EXTRACT(MONTH FROM s.dtped) = 12 THEN '05'
                ELSE s.filial
            END as filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            sup.nome as superv,
            COALESCE(vend.nome, c.nomecliente) as nome,
            s.codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_supervisores sup ON s.codsupervisor = sup.codigo
        LEFT JOIN public.dim_vendedores vend ON s.codusur = vend.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.superv, pa.nome, pa.codfor, pa.tipovenda, pa.codcli,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            ARRAY_AGG(DISTINCT pa.produto) FILTER (WHERE pa.produto IS NOT NULL) as arr_prod,
            jsonb_object_agg(pa.produto, pa.prod_val) FILTER (WHERE pa.produto IS NOT NULL) as json_prod
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
    )
    SELECT
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        arr_prod, json_prod,
        (SELECT COUNT(*) FROM jsonb_each_text(json_prod) WHERE (value)::numeric >= 1 AND codfor IN ('707', '708')) as mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc
    FROM client_agg;

    CLUSTER public.data_summary USING idx_summary_ano_mes_filial;
    ANALYZE public.data_summary;
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. OPTIMIZED GET MAIN DASHBOARD DATA (Dynamic SQL)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_main_dashboard_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
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
    v_where_agg text := ' WHERE 1=1 ';
    v_where_kpi text := ' WHERE 1=1 ';
    v_result json;

    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_curr_month_idx int;
BEGIN
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '15s';

    -- 1. Determine Date Ranges
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
    ELSE
         SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year;
    END IF;

    -- 2. Trend Logic
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
        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric; ELSE v_trend_factor := 1; END IF;
    END IF;

    -- 3. Construct Pure Dynamic WHERE Clause
    -- Only add conditions if filters exist. Use literal values or params.
    -- Using $params is safer for injection, but strict Dynamic SQL needs proper indexing.

    -- Base Filters (Table: data_summary)
    v_where_base := v_where_base || format(' AND ano IN (%L, %L) ', v_current_year, v_previous_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;

    -- KPI Base Filter (Table: data_clients)
    -- "Na base": Clients not blocked, filtered by City only (usually)
    v_where_kpi := ' WHERE bloqueio != ''S'' ';
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_kpi := v_where_kpi || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    -- 4. Execute Main Query
    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda
        FROM public.data_summary
        ' || v_where_base || '
    ),
    agg_data AS (
        SELECT
            ano,
            mes,
            SUM(CASE
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN vlvenda
                WHEN tipovenda IN (''1'', ''9'') THEN vlvenda
                ELSE 0
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao,
            COUNT(DISTINCT CASE WHEN pre_positivacao_val = 1 THEN codcli END) as positivacao_count,
            SUM(CASE
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN pre_mix_count
                WHEN tipovenda IN (''1'', ''9'') THEN pre_mix_count
                ELSE 0
            END) as total_mix_sum,
            COUNT(DISTINCT CASE
                WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) AND pre_mix_count > 0 THEN codcli
                WHEN tipovenda IN (''1'', ''9'') AND pre_mix_count > 0 THEN codcli
                ELSE NULL
            END) as mix_client_count
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(DISTINCT codcli) as val
        FROM filtered_summary
        WHERE ano = $2 AND mes = $3 AND pre_positivacao_val = 1
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

    -- 5. Calculate Trend
    IF v_trend_allowed THEN
        v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;
        DECLARE v_elem json;
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


-- ------------------------------------------------------------------------------
-- 4. OPTIMIZED GET CITY DATA (Dynamic SQL + Pagination)
-- ------------------------------------------------------------------------------
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
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_target_month int;
    v_where text := ' WHERE 1=1 ';
    v_where_clients text := ' WHERE bloqueio != ''S'' ';
    v_sql text;
    v_active_clients json;
    v_inactive_clients json;
    v_total_active_count int;
    v_total_inactive_count int;
BEGIN
    SET LOCAL work_mem = '64MB';

    -- Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
         SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    -- Target month filter logic for summary
    v_where := v_where || format(' AND ano = %L ', v_current_year);
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_where := v_where || format(' AND mes = %L ', v_target_month);
    END IF;

    -- Dynamic Filters
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_clients := v_where_clients || format(' AND cidade = ANY(%L) ', p_cidade);
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

    -- ACTIVE CLIENTS QUERY
    v_sql := '
    WITH client_totals AS (
        SELECT codcli, SUM(vlvenda) as total_fat
        FROM public.data_summary
        ' || v_where || '
        GROUP BY codcli
        HAVING SUM(vlvenda) >= 1
    ),
    count_cte AS (SELECT COUNT(*) as cnt FROM client_totals),
    paginated_clients AS (
        SELECT ct.codcli, ct.total_fat, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.rca1
        FROM client_totals ct
        JOIN public.data_clients c ON c.codigo_cliente = ct.codcli
        ORDER BY ct.total_fat DESC
        LIMIT $1 OFFSET ($2 * $1)
    )
    SELECT
        (SELECT cnt FROM count_cte),
        json_agg(json_build_object(''Código'', pc.codcli, ''fantasia'', pc.fantasia, ''razaoSocial'', pc.razaosocial, ''totalFaturamento'', pc.total_fat, ''cidade'', pc.cidade, ''bairro'', pc.bairro, ''rca1'', pc.rca1) ORDER BY pc.total_fat DESC)
    FROM paginated_clients pc;
    ';

    EXECUTE v_sql INTO v_total_active_count, v_active_clients USING p_limit, p_page;

    -- INACTIVE CLIENTS QUERY (NOT EXISTS)
    -- We reuse v_where for the NOT EXISTS subquery
    v_sql := '
    WITH inactive_cte AS (
        SELECT c.codigo_cliente, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.ultimacompra, c.rca1
        FROM public.data_clients c
        ' || v_where_clients || '
        AND NOT EXISTS (
              SELECT 1 FROM public.data_summary s2
              ' || v_where || ' AND s2.codcli = c.codigo_cliente
        )
    ),
    count_inactive AS (SELECT COUNT(*) as cnt FROM inactive_cte),
    paginated_inactive AS (
        SELECT * FROM inactive_cte
        ORDER BY ultimacompra DESC NULLS LAST
        LIMIT $1 OFFSET ($2 * $1)
    )
    SELECT
        (SELECT cnt FROM count_inactive),
        json_agg(json_build_object(''Código'', pi.codigo_cliente, ''fantasia'', pi.fantasia, ''razaoSocial'', pi.razaosocial, ''cidade'', pi.cidade, ''bairro'', pi.bairro, ''ultimaCompra'', pi.ultimacompra, ''rca1'', pi.rca1) ORDER BY pi.ultimacompra DESC NULLS LAST)
    FROM paginated_inactive pi;
    ';

    EXECUTE v_sql INTO v_total_inactive_count, v_inactive_clients USING p_inactive_limit, p_inactive_page;

    RETURN json_build_object(
        'active_clients', COALESCE(v_active_clients, '[]'::json),
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', COALESCE(v_inactive_clients, '[]'::json),
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. NEW RPC: GET BRANCH COMPARISON (Aggregated)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_branch_comparison_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_current_year int;
    v_target_month int;

    -- Trend
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_curr_month_idx int;

    -- Dynamic SQL
    v_where text := ' WHERE 1=1 ';
    v_sql text;
    v_result json;
BEGIN
    SET LOCAL work_mem = '64MB';

    -- 1. Date & Trend Setup (Simplified)
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_target_month := p_mes::int + 1;
    ELSE SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year; END IF;

    -- Trend Calculation (Copy from Main)
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;
    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN v_trend_allowed := false; END IF;
    END IF;

    IF v_trend_allowed THEN
         DECLARE
            v_month_start date := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
            v_month_end date := (v_month_start + interval '1 month' - interval '1 day')::date;
            v_days_passed int := public.calc_working_days(v_month_start, v_max_sale_date);
            v_days_total int := public.calc_working_days(v_month_start, v_month_end);
         BEGIN
            IF v_days_passed > 0 AND v_days_total > 0 THEN v_trend_factor := v_days_total::numeric / v_days_passed::numeric; END IF;
         END;
         v_curr_month_idx := EXTRACT(MONTH FROM v_max_sale_date)::int - 1;
    END IF;

    -- 2. Build Where
    v_where := v_where || format(' AND ano = %L ', v_current_year);

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN v_where := v_where || format(' AND filial = ANY(%L) ', p_filial); END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade); END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN v_where := v_where || format(' AND superv = ANY(%L) ', p_supervisor); END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN v_where := v_where || format(' AND nome = ANY(%L) ', p_vendedor); END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

    -- 3. Execute
    v_sql := '
    WITH agg_filial AS (
        SELECT
            filial,
            mes,
            SUM(CASE WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN vlvenda WHEN tipovenda IN (''1'', ''9'') THEN vlvenda ELSE 0 END) as faturamento,
            SUM(peso) as peso
        FROM public.data_summary
        ' || v_where || '
        GROUP BY filial, mes
    )
    SELECT json_object_agg(filial, data)
    FROM (
        SELECT filial, json_build_object(
            ''monthly_data_current'', json_agg(json_build_object(
                ''month_index'', mes - 1,
                ''faturamento'', faturamento,
                ''peso'', peso
            ) ORDER BY mes),
            ''trend_allowed'', $2,
            ''trend_data'', CASE WHEN $2 THEN
                 (SELECT json_build_object(''month_index'', mes - 1, ''faturamento'', faturamento * $3, ''peso'', peso * $3)
                  FROM agg_filial sub
                  WHERE sub.filial = agg_filial.filial AND sub.mes = ($4 + 1))
            ELSE null END
        ) as data
        FROM agg_filial
        GROUP BY filial
    ) t;
    ';

    EXECUTE v_sql INTO v_result USING p_tipovenda, v_trend_allowed, v_trend_factor, v_curr_month_idx;

    RETURN COALESCE(v_result, '{}'::json);
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. INITIALIZATION & REFRESH
-- ------------------------------------------------------------------------------
-- Ensure summary table is populated immediately
SELECT refresh_cache_summary();
