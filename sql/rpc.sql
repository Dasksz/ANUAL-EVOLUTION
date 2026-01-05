
-- Function to clear data before full upload (optional, if user wants to replace everything)
CREATE OR REPLACE FUNCTION clear_all_data()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM public.data_detailed;
    DELETE FROM public.data_history;
    DELETE FROM public.data_clients;
END;
$$;

-- Function: Get Main Dashboard Data (Optimized with Dynamic SQL)
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
    v_start_date_curr date;
    v_end_date_curr date;
    v_start_date_prev date;
    v_end_date_prev date;

    v_kpi_clients_attended int;
    v_kpi_clients_base int;

    v_monthly_chart_current json;
    v_monthly_chart_previous json;

    v_result json;

    -- Dynamic SQL variables
    v_sql text;
    v_where_common text;
    v_where_tipovenda text;
BEGIN
    -- Increase timeout for large data aggregation
    SET LOCAL statement_timeout = '120s';

    -- 1. Determine Years and Dates
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        -- Check both tables to find the true latest year
        SELECT COALESCE(GREATEST(
            (SELECT MAX(EXTRACT(YEAR FROM dtped))::int FROM public.data_detailed),
            (SELECT MAX(EXTRACT(YEAR FROM dtped))::int FROM public.data_history)
        ), EXTRACT(YEAR FROM CURRENT_DATE)::int)
        INTO v_current_year;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    -- Define Date Ranges
    v_start_date_curr := make_date(v_current_year, 1, 1);
    v_end_date_curr := make_date(v_current_year + 1, 1, 1);
    v_start_date_prev := make_date(v_previous_year, 1, 1);
    v_end_date_prev := make_date(v_previous_year + 1, 1, 1);

    -- 2. Determine Month Filter
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1; -- JS is 0-indexed
    ELSE
         -- Find last month with sales in current year by checking both tables
         SELECT COALESCE(GREATEST(
            (SELECT EXTRACT(MONTH FROM MAX(dtped))::int FROM public.data_detailed WHERE dtped >= v_start_date_curr AND dtped < v_end_date_curr),
            (SELECT EXTRACT(MONTH FROM MAX(dtped))::int FROM public.data_history WHERE dtped >= v_start_date_curr AND dtped < v_end_date_curr)
         ), 12) -- Default to Dec if null
         INTO v_target_month;
    END IF;

    -- 3. Construct Dynamic WHERE Clauses
    -- Common Filters (Supervisor, Vendedor, etc.)
    v_where_common := '';

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND filial = ANY(%L) ', p_filial);
    END IF;

    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;

    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND superv = ANY(%L) ', p_supervisor);
    END IF;

    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND nome = ANY(%L) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;

    -- Tipo Venda Filter Logic
    -- If explicit filter provided, add to WHERE.
    -- If NOT provided, we do NOT filter in WHERE because we need ALL types for Positivacao (val_venda_total).
    -- However, we construct a CASE condition string for 'val_venda' (Revenue) calculation.
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        -- If filtered, Revenue is just Sum(vlvenda) because rows are already filtered
        v_where_tipovenda := ' vlvenda ';
    ELSE
        -- Default Logic: Revenue = Type '1' only (Fixing Billing Discrepancy by removing '9')
        -- Old Logic was: tipovenda IN ('1', '9')
        v_where_tipovenda := ' CASE WHEN tipovenda = ''1'' THEN vlvenda ELSE 0 END ';
    END IF;


    -- 4. Construct Full Query
    v_sql := format('
    WITH detailed_base AS (
        SELECT
            EXTRACT(YEAR FROM dtped)::int as yr,
            EXTRACT(MONTH FROM dtped)::int as mth,
            codcli,
            SUM(%s) as val_venda,
            SUM(vlvenda) as val_venda_total, -- Always sum all for Positivacao
            SUM(totpesoliq) as val_peso,
            SUM(vlbonific) as val_bonif,
            SUM(COALESCE(vldevolucao,0)) as val_devol
        FROM public.data_detailed
        WHERE dtped >= %L AND dtped < %L
        %s
        GROUP BY 1, 2, 3
    ),
    detailed_agg AS (
        SELECT
            yr,
            mth,
            SUM(val_venda) as faturamento,
            SUM(val_peso) as peso,
            SUM(val_bonif) as bonificacao,
            SUM(val_devol) as devolucao,
            COUNT(DISTINCT CASE WHEN val_venda_total >= 1 THEN codcli END) as positivacao
        FROM detailed_base
        GROUP BY 1, 2
    ),
    history_base AS (
        SELECT
            EXTRACT(YEAR FROM dtped)::int as yr,
            EXTRACT(MONTH FROM dtped)::int as mth,
            codcli,
            SUM(%s) as val_venda,
            SUM(vlvenda) as val_venda_total,
            SUM(totpesoliq) as val_peso,
            SUM(vlbonific) as val_bonif,
            SUM(COALESCE(vldevolucao,0)) as val_devol
        FROM public.data_history
        WHERE dtped >= %L AND dtped < %L
        %s
        GROUP BY 1, 2, 3
    ),
    history_agg AS (
        SELECT
            yr,
            mth,
            SUM(val_venda) as faturamento,
            SUM(val_peso) as peso,
            SUM(val_bonif) as bonificacao,
            SUM(val_devol) as devolucao,
            COUNT(DISTINCT CASE WHEN val_venda_total >= 1 THEN codcli END) as positivacao
        FROM history_base
        GROUP BY 1, 2
    ),
    combined_agg AS (
        SELECT
            COALESCE(d.yr, h.yr) as yr,
            COALESCE(d.mth, h.mth) as mth,
            COALESCE(d.faturamento, 0) + COALESCE(h.faturamento, 0) as faturamento,
            COALESCE(d.peso, 0) + COALESCE(h.peso, 0) as peso,
            COALESCE(d.bonificacao, 0) + COALESCE(h.bonificacao, 0) as bonificacao,
            COALESCE(d.devolucao, 0) + COALESCE(h.devolucao, 0) as devolucao,
            COALESCE(d.positivacao, 0) + COALESCE(h.positivacao, 0) as positivacao
        FROM detailed_agg d
        FULL OUTER JOIN history_agg h ON d.yr = h.yr AND d.mth = h.mth
    ),
    kpi_active_clients AS (
        SELECT COUNT(*) as val
        FROM (
             SELECT codcli
             FROM public.data_detailed
             WHERE dtped >= %L
               AND dtped <  (%L::date + interval ''1 month'')
               %s
             GROUP BY codcli
             HAVING SUM(vlvenda) >= 1
             UNION
             SELECT codcli
             FROM public.data_history
             WHERE dtped >= %L
               AND dtped <  (%L::date + interval ''1 month'')
               %s
             GROUP BY codcli
             HAVING SUM(vlvenda) >= 1
        ) t
    ),
    relevant_rcas AS (
        SELECT DISTINCT codusur
        FROM public.data_detailed
        WHERE dtped >= %L AND dtped < %L
        %s
        UNION
        SELECT DISTINCT codusur
        FROM public.data_history
        WHERE dtped >= %L AND dtped < %L
        %s
    )
    SELECT
        (SELECT val FROM kpi_active_clients),
        CASE 
            WHEN (%L IS NULL AND %L IS NULL) THEN
                (SELECT COUNT(*) FROM public.data_clients c WHERE c.bloqueio != ''S''
                 %s -- City filter only
                )
            ELSE
                (SELECT COUNT(*) FROM public.data_clients c WHERE c.bloqueio != ''S''
                 %s -- City filter
                 AND c.rca1 IN (SELECT codusur FROM relevant_rcas))
        END,
        COALESCE(json_agg(json_build_object(
            ''month_index'', mth - 1,
            ''faturamento'', faturamento,
            ''peso'', peso,
            ''bonificacao'', bonificacao,
            ''devolucao'', devolucao,
            ''positivacao'', positivacao
        ) ORDER BY mth) FILTER (WHERE yr = %L), ''[]''::json),
        COALESCE(json_agg(json_build_object(
            ''month_index'', mth - 1,
            ''faturamento'', faturamento,
            ''peso'', peso,
            ''bonificacao'', bonificacao,
            ''devolucao'', devolucao,
            ''positivacao'', positivacao
        ) ORDER BY mth) FILTER (WHERE yr = %L), ''[]''::json)
    FROM combined_agg
    ',
    v_where_tipovenda, v_start_date_prev, v_end_date_curr, v_where_common, -- detailed_base
    v_where_tipovenda, v_start_date_prev, v_end_date_curr, v_where_common, -- history_base
    -- KPI Active Clients
    make_date(v_current_year, v_target_month, 1), make_date(v_current_year, v_target_month, 1), v_where_common,
    make_date(v_current_year, v_target_month, 1), make_date(v_current_year, v_target_month, 1), v_where_common,
    -- Relevant RCAs
    v_start_date_curr, v_end_date_curr, v_where_common,
    v_start_date_curr, v_end_date_curr, v_where_common,
    -- Select Params
    p_supervisor, p_vendedor,
    -- Clients Base Filters
    CASE WHEN p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN format(' AND c.cidade = ANY(%L) ', p_cidade) ELSE '' END,
    CASE WHEN p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN format(' AND c.cidade = ANY(%L) ', p_cidade) ELSE '' END,
    -- Years
    v_current_year, v_previous_year
    );

    EXECUTE v_sql INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous;

    -- 5. Result
    v_result := json_build_object(
        'current_year', v_current_year,
        'previous_year', v_previous_year,
        'target_month_index', v_target_month - 1,
        'kpi_clients_attended', COALESCE(v_kpi_clients_attended, 0),
        'kpi_clients_base', COALESCE(v_kpi_clients_base, 0),
        'monthly_data_current', v_monthly_chart_current,
        'monthly_data_previous', v_monthly_chart_previous
    );

    RETURN v_result;
END;
$$;

-- Function: Get City View Data (Optimized with Dynamic SQL)
CREATE OR REPLACE FUNCTION get_city_view_data(
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
    v_target_month int;
    v_start_date date;
    v_end_date date;
    v_result json;
    v_active_clients json;
    v_inactive_clients json;

    v_sql text;
    v_where_common text;
BEGIN
    -- Defaults
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
         SELECT COALESCE(MAX(EXTRACT(YEAR FROM dtped))::int, EXTRACT(YEAR FROM CURRENT_DATE)::int)
         INTO v_current_year
         FROM public.all_sales;
    ELSE
        v_current_year := p_ano::int;
    END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1; -- JS 0-based -> SQL 1-based
    ELSE
         -- Default to last month with sales in current year
         SELECT EXTRACT(MONTH FROM MAX(dtped))::int INTO v_target_month
         FROM public.all_sales
         WHERE dtped >= make_date(v_current_year, 1, 1)
           AND dtped < make_date(v_current_year + 1, 1, 1);
    END IF;
    IF v_target_month IS NULL THEN v_target_month := 12; END IF;

    -- Define target date range
    v_start_date := make_date(v_current_year, v_target_month, 1);
    v_end_date := v_start_date + interval '1 month';

    -- Dynamic WHERE Construction
    v_where_common := '';
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN v_where_common := v_where_common || format(' AND filial = ANY(%L) ', p_filial); END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN v_where_common := v_where_common || format(' AND cidade = ANY(%L) ', p_cidade); END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN v_where_common := v_where_common || format(' AND superv = ANY(%L) ', p_supervisor); END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN v_where_common := v_where_common || format(' AND nome = ANY(%L) ', p_vendedor); END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_where_common := v_where_common || format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_where_common := v_where_common || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

    -- Active Clients Query
    v_sql := format('
    WITH client_totals AS (
        SELECT codcli, SUM(vlvenda) as total_fat
        FROM public.all_sales
        WHERE dtped >= %L AND dtped < %L
        %s
        GROUP BY codcli
        HAVING SUM(vlvenda) > 0
    )
    SELECT json_agg(
        json_build_object(
            ''Código'', c.codigo_cliente,
            ''fantasia'', c.fantasia,
            ''razaoSocial'', c.razaosocial,
            ''totalFaturamento'', ct.total_fat,
            ''cidade'', c.cidade,
            ''bairro'', c.bairro,
            ''rca1'', c.rca1,
            ''rca2'', c.rca2
        ) ORDER BY ct.total_fat DESC
    )
    FROM client_totals ct
    JOIN public.data_clients c ON c.codigo_cliente = ct.codcli;
    ', v_start_date, v_end_date, v_where_common);

    EXECUTE v_sql INTO v_active_clients;

    -- Inactive Clients Query
    -- Need to reconstruct conditions specifically for the Inactive Logic (checking inactivity over current year)
    v_sql := format('
    WITH relevant_rcas AS (
        SELECT DISTINCT codusur
        FROM public.all_sales s
        WHERE dtped >= %L AND dtped < %L -- Current Year
        %s -- Apply Supervisor/Vendedor filters to find relevant RCAs
    )
    SELECT json_agg(
        json_build_object(
            ''Código'', c.codigo_cliente,
            ''fantasia'', c.fantasia,
            ''razaoSocial'', c.razaosocial,
            ''cidade'', c.cidade,
            ''bairro'', c.bairro,
            ''ultimaCompra'', c.ultimacompra,
            ''rca1'', c.rca1,
            ''rca2'', c.rca2
        ) ORDER BY c.ultimacompra DESC NULLS LAST
    )
    FROM public.data_clients c
    WHERE c.bloqueio != ''S''
      %s -- Cidade Filter
      AND (
          (%L IS NULL AND %L IS NULL) -- If no RCA filters
          OR
          (c.rca1 IN (SELECT codusur FROM relevant_rcas))
      )
      AND NOT EXISTS (
          SELECT 1
          FROM public.all_sales s2
          WHERE s2.codcli = c.codigo_cliente
            AND s2.dtped >= %L AND s2.dtped < %L -- Target Month
            %s -- All Filters (must not have bought in target month matching filters)
      );
    ',
    make_date(v_current_year, 1, 1), make_date(v_current_year + 1, 1, 1),
    CASE
        WHEN p_supervisor IS NOT NULL OR p_vendedor IS NOT NULL THEN
            (CASE WHEN p_supervisor IS NOT NULL THEN format(' AND s.superv = ANY(%L) ', p_supervisor) ELSE '' END) ||
            (CASE WHEN p_vendedor IS NOT NULL THEN format(' AND s.nome = ANY(%L) ', p_vendedor) ELSE '' END)
        ELSE ' AND 1=1 ' -- Should optimize out if used correctly above, but logic requires careful handling
    END,
    CASE WHEN p_cidade IS NOT NULL THEN format(' AND c.cidade = ANY(%L) ', p_cidade) ELSE '' END,
    p_supervisor, p_vendedor,
    v_start_date, v_end_date,
    v_where_common
    );

    EXECUTE v_sql INTO v_inactive_clients;

    v_result := json_build_object(
        'active_clients', COALESCE(v_active_clients, '[]'::json),
        'inactive_clients', COALESCE(v_inactive_clients, '[]'::json)
    );

    RETURN v_result;
END;
$$;

-- Function: Get Filters (Optimized with Dynamic SQL)
CREATE OR REPLACE FUNCTION get_dashboard_filters(
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
    v_supervisors text[];
    v_vendedores text[];
    v_fornecedores json;
    v_cidades text[];
    v_filiais text[];
    v_anos int[];
    v_tipos_venda text[];
    
    v_filter_year int;
    v_filter_month int;

    v_sql text;
    v_where_base text;

    v_cond_filial text;
    v_cond_cidade text;
    v_cond_superv text;
    v_cond_vendedor text;
    v_cond_fornecedor text;
    v_cond_tipovenda text;
    v_cond_mes text;
    v_cond_year text;
BEGIN
    SET LOCAL statement_timeout = '120s';

    -- Handle Year
    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
        v_cond_year := format(' AND ano = %L ', v_filter_year);
    ELSE
         -- Default year handling logic (kept simple for dynamic SQL: if null, no filter on 'ano' column if it relies on cache table having all years)
         -- But original logic filtered by max year if null?
         -- "Default to Current + Previous Year if no year selected" -> Actually the cache table query used `WHERE (v_filter_year IS NULL OR ano = v_filter_year)`.
         -- If v_filter_year is null, it returns all years.
         v_cond_year := '';
    END IF;
    
    -- Handle Month
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_filter_month := p_mes::int + 1;
        v_cond_mes := format(' AND mes = %L ', v_filter_month);
    ELSE
        v_cond_mes := '';
    END IF;

    -- Build Condition Strings
    v_cond_filial := ''; IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN v_cond_filial := format(' AND filial = ANY(%L) ', p_filial); END IF;
    v_cond_cidade := ''; IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN v_cond_cidade := format(' AND cidade = ANY(%L) ', p_cidade); END IF;
    v_cond_superv := ''; IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN v_cond_superv := format(' AND superv = ANY(%L) ', p_supervisor); END IF;
    v_cond_vendedor := ''; IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN v_cond_vendedor := format(' AND nome = ANY(%L) ', p_vendedor); END IF;
    v_cond_fornecedor := ''; IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_cond_fornecedor := format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    v_cond_tipovenda := ''; IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_cond_tipovenda := format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

    v_where_base := ' WHERE 1=1 ' || v_cond_year;

    -- Construct the Big Query
    -- Note: FILTER clauses need to exclude their own condition
    
    v_sql := format('
    SELECT
        -- 1. Supervisors (Exclude supervisor filter)
        ARRAY_AGG(DISTINCT superv ORDER BY superv) FILTER (WHERE 1=1 %s %s %s %s %s %s),
        -- 2. Vendedores (Exclude vendedor filter)
        ARRAY_AGG(DISTINCT nome ORDER BY nome) FILTER (WHERE 1=1 %s %s %s %s %s %s),
        -- 3. Cidades (Exclude cidade filter)
        ARRAY_AGG(DISTINCT cidade ORDER BY cidade) FILTER (WHERE 1=1 %s %s %s %s %s %s),
        -- 4. Filiais (Exclude filial filter)
        ARRAY_AGG(DISTINCT filial ORDER BY filial) FILTER (WHERE 1=1 %s %s %s %s %s %s),
        -- 5. Tipos de Venda (Exclude tipovenda filter)
        ARRAY_AGG(DISTINCT tipovenda ORDER BY tipovenda) FILTER (WHERE tipovenda IS NOT NULL AND tipovenda != '''' AND tipovenda != ''null'' %s %s %s %s %s %s)
    FROM public.cache_filters
    %s
    ',
    -- 1. Supervisors: exclude v_cond_superv
    v_cond_filial, v_cond_cidade, v_cond_vendedor, v_cond_fornecedor, v_cond_tipovenda, v_cond_mes,
    -- 2. Vendedores: exclude v_cond_vendedor
    v_cond_filial, v_cond_cidade, v_cond_superv, v_cond_fornecedor, v_cond_tipovenda, v_cond_mes,
    -- 3. Cidades: exclude v_cond_cidade
    v_cond_filial, v_cond_superv, v_cond_vendedor, v_cond_fornecedor, v_cond_tipovenda, v_cond_mes,
    -- 4. Filiais: exclude v_cond_filial
    v_cond_cidade, v_cond_superv, v_cond_vendedor, v_cond_fornecedor, v_cond_tipovenda, v_cond_mes,
    -- 5. Tipos Venda: exclude v_cond_tipovenda
    v_cond_filial, v_cond_cidade, v_cond_superv, v_cond_vendedor, v_cond_fornecedor, v_cond_mes,
    -- Base WHERE
    v_where_base
    );

    EXECUTE v_sql INTO v_supervisors, v_vendedores, v_cidades, v_filiais, v_tipos_venda;

    -- 6. Fornecedores (Separate query logic kept or integrated? Integrated is harder due to JSON transform. Keep separate but dynamic)
    -- Exclude fornecedor filter
    v_sql := format('
    SELECT json_agg(json_build_object(''cod'', codfor, ''name'',
        CASE 
            WHEN codfor = ''707'' THEN ''Extrusados''
            WHEN codfor = ''708'' THEN ''Ñ Extrusados''
            WHEN codfor = ''752'' THEN ''Torcida''
            WHEN codfor = ''1119'' THEN ''Foods''
            ELSE fornecedor 
        END
    ) ORDER BY 
        CASE 
            WHEN codfor = ''707'' THEN ''Extrusados''
            WHEN codfor = ''708'' THEN ''Ñ Extrusados''
            WHEN codfor = ''752'' THEN ''Torcida''
            WHEN codfor = ''1119'' THEN ''Foods''
            ELSE fornecedor 
        END
    )
    FROM (
        SELECT DISTINCT codfor, fornecedor
        FROM public.cache_filters
        %s -- Base Where (Year)
        AND codfor IS NOT NULL
        %s %s %s %s %s %s -- All filters EXCEPT fornecedor
    ) t
    ',
    v_where_base,
    v_cond_filial, v_cond_cidade, v_cond_superv, v_cond_vendedor, v_cond_tipovenda, v_cond_mes
    );

    EXECUTE v_sql INTO v_fornecedores;

    -- 7. Anos
    v_sql := format('
    SELECT ARRAY_AGG(DISTINCT ano ORDER BY ano DESC)
    FROM public.cache_filters
    WHERE 1=1
    %s %s %s %s %s %s %s -- All filters
    ',
    v_cond_filial, v_cond_cidade, v_cond_superv, v_cond_vendedor, v_cond_fornecedor, v_cond_tipovenda, v_cond_mes
    );

    EXECUTE v_sql INTO v_anos;

    RETURN json_build_object(
        'supervisors', COALESCE(v_supervisors, '{}'),
        'vendedores', COALESCE(v_vendedores, '{}'),
        'fornecedores', COALESCE(v_fornecedores, '[]'::json),
        'cidades', COALESCE(v_cidades, '{}'),
        'filiais', COALESCE(v_filiais, '{}'),
        'anos', COALESCE(v_anos, '{}'),
        'tipos_venda', COALESCE(v_tipos_venda, '{}')
    );
END;
$$;
