-- Migration V2: Remove RCA2, Add Holidays, Optimize, Add Trend Logic

-- 1. Remove RCA 2 Column (if exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_clients' AND column_name = 'rca2') THEN
        ALTER TABLE public.data_clients DROP COLUMN rca2;
    END IF;
END $$;

-- 2. Create Holidays Table
CREATE TABLE IF NOT EXISTS public.data_holidays (
    date date PRIMARY KEY,
    description text
);

-- Enable RLS for Holidays
ALTER TABLE public.data_holidays ENABLE ROW LEVEL SECURITY;

-- Policies for Holidays (Admin manage, Everyone read)
DROP POLICY IF EXISTS "Read Access Approved" ON public.data_holidays;
CREATE POLICY "Read Access Approved" ON public.data_holidays FOR SELECT USING (public.is_approved());

DROP POLICY IF EXISTS "Write Access Admin" ON public.data_holidays;
CREATE POLICY "Write Access Admin" ON public.data_holidays FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delete Access Admin" ON public.data_holidays;
CREATE POLICY "Delete Access Admin" ON public.data_holidays FOR DELETE USING (public.is_admin());

-- 3. Toggle Holiday RPC
CREATE OR REPLACE FUNCTION toggle_holiday(p_date date)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RETURN 'Acesso negado.';
    END IF;

    IF EXISTS (SELECT 1 FROM public.data_holidays WHERE date = p_date) THEN
        DELETE FROM public.data_holidays WHERE date = p_date;
        RETURN 'Feriado removido.';
    ELSE
        INSERT INTO public.data_holidays (date, description) VALUES (p_date, 'Feriado Manual');
        RETURN 'Feriado adicionado.';
    END IF;
END;
$$;

-- 4. Helper: Calculate Working Days
CREATE OR REPLACE FUNCTION calc_working_days(start_date date, end_date date)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
    days int;
BEGIN
    SELECT COUNT(*)
    INTO days
    FROM generate_series(start_date, end_date, '1 day'::interval) AS d
    WHERE EXTRACT(ISODOW FROM d) < 6 -- Mon-Fri (1-5)
      AND d::date NOT IN (SELECT date FROM public.data_holidays);

    RETURN days;
END;
$$;

-- 5. Updated get_main_dashboard_data (with Trend Logic)
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
AS $$
DECLARE
    v_current_year int;
    v_previous_year int;
    v_target_month int;
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_result json;

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_work_days_passed int;
    v_work_days_total int;
    v_trend_factor numeric;
    v_trend_data json;
    v_month_start date;
    v_month_end date;
    v_holidays json;
BEGIN
    SET LOCAL statement_timeout = '600s';

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

    -- Determine if Trend Should be Calculated
    -- Rules: "only when filtered all years, current year or current month"
    -- p_ano is 'todos' (NULL/empty in param check above) OR p_ano is current year.
    -- p_mes is current month (implicit if selected).
    -- Simplified: If we are viewing the latest available year/month context, show trend.

    -- 1. Find Max Date in Data Detailed (Proxy for "Today")
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;

    -- If no data detailed, fallback to current date or disable trend
    IF v_max_sale_date IS NULL THEN
        v_max_sale_date := CURRENT_DATE;
    END IF;

    -- Check if target year/month matches the max date's year/month
    -- If user selected a past year, no trend.
    v_trend_allowed := (v_current_year = EXTRACT(YEAR FROM v_max_sale_date)::int);

    -- If user selected a specific month, only show trend if it's the current max date's month
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
       IF (p_mes::int + 1) != EXTRACT(MONTH FROM v_max_sale_date)::int THEN
           v_trend_allowed := false;
       END IF;
    END IF;

    -- Calculate Trend Factor
    IF v_trend_allowed THEN
        v_month_start := make_date(v_current_year, EXTRACT(MONTH FROM v_max_sale_date)::int, 1);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;

        -- Cap max date at month end (sanity check)
        IF v_max_sale_date > v_month_end THEN v_max_sale_date := v_month_end; END IF;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        ELSE
            v_trend_factor := 1;
        END IF;
    ELSE
        v_trend_factor := 0;
    END IF;

    WITH filtered_summary AS (
        SELECT *
        FROM public.data_summary
        WHERE ano IN (v_current_year, v_previous_year)
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
    ),
    client_monthly_stats AS (
        SELECT
            ano,
            mes,
            codcli,
            SUM(vlvenda) as total_val
        FROM filtered_summary
        GROUP BY 1, 2, 3
    ),
    monthly_positivation AS (
        SELECT
            ano,
            mes,
            COUNT(DISTINCT codcli) as positivacao_count
        FROM client_monthly_stats
        WHERE total_val >= 1
        GROUP BY 1, 2
    ),
    agg_data AS (
        SELECT
            ano,
            mes,
            SUM(CASE
                WHEN (p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0) THEN vlvenda
                WHEN tipovenda IN ('1', '9') THEN vlvenda
                ELSE 0
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(*) as val
        FROM (
             SELECT codcli
             FROM filtered_summary
             WHERE ano = v_current_year AND mes = v_target_month
             GROUP BY codcli
             HAVING SUM(vlvenda) >= 1
        ) t
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT COUNT(*) FROM public.data_clients c WHERE c.bloqueio != 'S' AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR c.cidade = ANY(p_cidade))),
        COALESCE(json_agg(json_build_object('month_index', a.mes - 1, 'faturamento', a.faturamento, 'peso', a.peso, 'bonificacao', a.bonificacao, 'devolucao', a.devolucao, 'positivacao', COALESCE(p.positivacao_count, 0)) ORDER BY a.mes) FILTER (WHERE a.ano = v_current_year), '[]'::json),
        COALESCE(json_agg(json_build_object('month_index', a.mes - 1, 'faturamento', a.faturamento, 'peso', a.peso, 'bonificacao', a.bonificacao, 'devolucao', a.devolucao, 'positivacao', COALESCE(p.positivacao_count, 0)) ORDER BY a.mes) FILTER (WHERE a.ano = v_previous_year), '[]'::json)
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    FROM agg_data a
    LEFT JOIN monthly_positivation p ON a.ano = p.ano AND a.mes = p.mes;

    -- Calculate Trend Values based on Current Month Data (which is inside v_monthly_chart_current)
    -- We need to extract the specific month's data to apply the factor
    -- Alternatively, we can calculate it here from agg_data again or process in JS.
    -- Processing in SQL is safer.

    IF v_trend_allowed THEN
        SELECT json_build_object(
            'month_index', EXTRACT(MONTH FROM v_max_sale_date)::int - 1,
            'faturamento', (d.faturamento * v_trend_factor),
            'peso', (d.peso * v_trend_factor),
            'bonificacao', (d.bonificacao * v_trend_factor),
            'devolucao', (d.devolucao * v_trend_factor),
            'positivacao', (COALESCE(p.positivacao_count, 0) * v_trend_factor)::int -- Rough estimate for pos
        ) INTO v_trend_data
        FROM agg_data d
        LEFT JOIN monthly_positivation p ON d.ano = p.ano AND d.mes = p.mes
        WHERE d.ano = v_current_year AND d.mes = EXTRACT(MONTH FROM v_max_sale_date)::int;
    END IF;

    -- Get Holidays for Calendar
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

-- 6. Updated get_city_view_data (Remove RCA2)
-- Drop old one first to allow return type change (although JSON is same type, internal structure changes are fine)
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
        SELECT ct.codcli, ct.total_fat, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.rca1
        FROM client_totals ct
        JOIN public.data_clients c ON c.codigo_cliente = ct.codcli
        ORDER BY ct.total_fat DESC
        LIMIT p_limit OFFSET (p_page * p_limit)
    )
    SELECT (SELECT cnt FROM count_cte), json_agg(json_build_object('Código', pc.codcli, 'fantasia', pc.fantasia, 'razaoSocial', pc.razaosocial, 'totalFaturamento', pc.total_fat, 'cidade', pc.cidade, 'bairro', pc.bairro, 'rca1', pc.rca1) ORDER BY pc.total_fat DESC)
    INTO v_total_active_count, v_active_clients
    FROM paginated_clients pc;

    -- Inactive Clients (Paginated)
    WITH inactive_cte AS (
        SELECT c.codigo_cliente, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.ultimacompra, c.rca1
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
        json_build_object('Código', pi.codigo_cliente, 'fantasia', pi.fantasia, 'razaoSocial', pi.razaosocial, 'cidade', pi.cidade, 'bairro', pi.bairro, 'ultimaCompra', pi.ultimacompra, 'rca1', pi.rca1)
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

-- 7. Add Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_summary_codcli ON public.data_summary(codcli);
CREATE INDEX IF NOT EXISTS idx_clients_cidade ON public.data_clients(cidade);
-- Optimized for finding Max Date efficiently
CREATE INDEX IF NOT EXISTS idx_detailed_dtped_desc ON public.data_detailed(dtped DESC);

-- 8. Updated optimize_database RPC
CREATE OR REPLACE FUNCTION optimize_database()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RETURN 'Acesso negado: Apenas administradores podem otimizar o banco.';
    END IF;

    -- Drop heavy indexes
    DROP INDEX IF EXISTS public.idx_detailed_dtped_composite;
    DROP INDEX IF EXISTS public.idx_history_dtped_composite;
    DROP INDEX IF EXISTS public.idx_summary_main;

    -- Recreate optimized indexes
    CREATE INDEX idx_detailed_dtped_composite ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor);
    CREATE INDEX idx_history_dtped_composite ON public.data_history (dtped, filial, cidade, superv, nome, codfor);
    CREATE INDEX idx_summary_main ON public.data_summary (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);

    -- New Performance Indexes
    CREATE INDEX IF NOT EXISTS idx_summary_codcli ON public.data_summary(codcli);
    CREATE INDEX IF NOT EXISTS idx_clients_cidade ON public.data_clients(cidade);
    CREATE INDEX IF NOT EXISTS idx_detailed_dtped_desc ON public.data_detailed(dtped DESC);

    RETURN 'Banco de dados otimizado com sucesso! Índices reconstruídos.';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erro ao otimizar banco: ' || SQLERRM;
END;
$$;
