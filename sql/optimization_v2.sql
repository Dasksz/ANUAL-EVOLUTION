-- ==============================================================================
-- OPTIMIZATION V2: Reduce Storage & Improve Performance
-- 1. Populate dim_produtos from history/detailed (prevent data loss)
-- 2. Drop unused text columns from data_detailed/data_history
-- 3. Optimize data_summary to use codes instead of text
-- 4. Update RPCs to handle schema changes
-- ==============================================================================

-- 1. Populate dim_produtos
INSERT INTO public.dim_produtos (codigo, descricao, codfor)
SELECT DISTINCT s.produto, s.descricao, s.codfor
FROM public.data_detailed s
WHERE s.produto IS NOT NULL AND s.produto != ''
  AND NOT EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = s.produto)
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO public.dim_produtos (codigo, descricao, codfor)
SELECT DISTINCT s.produto, s.descricao, s.codfor
FROM public.data_history s
WHERE s.produto IS NOT NULL AND s.produto != ''
  AND NOT EXISTS (SELECT 1 FROM public.dim_produtos dp WHERE dp.codigo = s.produto)
ON CONFLICT (codigo) DO NOTHING;

-- 2. Drop unused columns
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS cliente_nome;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS bairro;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS observacaofor;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS descricao;

ALTER TABLE public.data_history DROP COLUMN IF EXISTS cliente_nome;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS bairro;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS observacaofor;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS descricao;

-- 3. Recreate data_summary with codes
DROP TABLE IF EXISTS public.data_summary CASCADE;
CREATE TABLE IF NOT EXISTS public.data_summary (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    ano int,
    mes int,
    filial text,
    cidade text,
    codsupervisor text, -- Replaces superv (name)
    codusur text,       -- Replaces nome (name)
    codfor text,
    tipovenda text,
    codcli text,
    vlvenda numeric,
    peso numeric,
    bonificacao numeric,
    devolucao numeric,
    pre_mix_count int DEFAULT 0,
    pre_positivacao_val int DEFAULT 0,
    ramo text,
    caixas numeric DEFAULT 0,
    created_at timestamp with time zone default now()
);

-- RLS
ALTER TABLE public.data_summary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Unified Read Access" ON public.data_summary FOR SELECT USING (public.is_approved());
CREATE POLICY "Admin Insert" ON public.data_summary FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "Admin Update" ON public.data_summary FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "Admin Delete" ON public.data_summary FOR DELETE USING (public.is_admin());

-- 4. Update RPCs

-- A. Refresh Cache Filters (Join dim_produtos for description)
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede)
    SELECT DISTINCT
        t.filial,
        COALESCE(t.cidade, c.cidade) as cidade,
        ds.nome as superv,
        COALESCE(dv.nome, c.nomecliente) as nome,
        CASE
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
            WHEN t.codfor = '1119' THEN '1119_OUTROS'
            ELSE t.codfor
        END as codfor,
        CASE
            WHEN t.codfor = '707' THEN 'EXTRUSADOS'
            WHEN t.codfor = '708' THEN 'Ñ EXTRUSADOS'
            WHEN t.codfor = '752' THEN 'TORCIDA'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%TODDYNHO%' THEN 'TODDYNHO'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%TODDY %' THEN 'TODDY'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%QUAKER%' THEN 'QUAKER'
            WHEN t.codfor = '1119' AND dp.descricao ILIKE '%KEROCOCO%' THEN 'KEROCOCO'
            WHEN t.codfor = '1119' THEN 'FOODS (Outros)'
            ELSE df.nome
        END as fornecedor,
        t.tipovenda,
        t.yr,
        t.mth,
        c.ramo as rede
    FROM (
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli, produto,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli, produto,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codvendedor = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo
    LEFT JOIN public.dim_produtos dp ON t.produto = dp.codigo;
END;
$$;

-- B. Refresh Summary (Use Codes)
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        pre_mix_count, pre_positivacao_val,
        ramo, caixas
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, qtvenda_embalagem_master
        FROM public.data_history
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
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
    ),
    product_agg AS (
        SELECT
            ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, ramo, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol,
            SUM(COALESCE(qtvenda_embalagem_master, 0)) as prod_caixas
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    ),
    client_agg AS (
        SELECT
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.codsupervisor, pa.codusur, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            SUM(pa.prod_caixas) as total_caixas,
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    )
    SELECT
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo,
        total_caixas
    FROM client_agg;

    ANALYZE public.data_summary;
END;
$$;

-- C. Optimize Database (New Indexes)
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

    -- Drop obsolete indexes
    DROP INDEX IF EXISTS public.idx_summary_comercial; -- Old name
    DROP INDEX IF EXISTS public.idx_summary_ano_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_nome;

    -- Create new indexes for codes
    CREATE INDEX IF NOT EXISTS idx_summary_composite_main ON public.data_summary (ano, mes, filial, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_codes ON public.data_summary (codsupervisor, codusur, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_supcode ON public.data_summary (ano, codsupervisor);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_usurcode ON public.data_summary (ano, codusur);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codfor ON public.data_summary (ano, codfor);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_tipovenda ON public.data_summary (ano, tipovenda);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codcli ON public.data_summary (ano, codcli);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_ramo ON public.data_summary (ano, ramo);

    -- Cluster
    BEGIN
        CLUSTER public.data_summary USING idx_summary_ano_filial;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN 'Banco de dados otimizado (v2).';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erro ao otimizar banco: ' || SQLERRM;
END;
$$;

-- D. Get Main Dashboard Data (Update filtering to use codes)
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
    p_produto text[] default null
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
    -- UPDATE: Use Codes for filtering
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codsupervisor IN (SELECT codigo FROM public.dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_base := v_where_base || format(' AND codusur IN (SELECT codigo FROM public.dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_base := v_where_base || format(' AND codfor = ANY(%L) ', p_fornecedor);
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

    -- SUPERVISOR LOGIC FOR KPI (Map Name -> Code -> RCA1)
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

    -- VENDEDOR LOGIC FOR KPI (Map Name -> Code -> RCA1)
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
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda, codfor
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

-- E. Get Boxes Dashboard (Join dim_produtos)
CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null
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
    v_ref_date date;
    v_tri_start date;
    v_tri_end date;

    v_where_summary text := ' WHERE 1=1 ';
    v_where_raw text := ' WHERE 1=1 ';

    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_use_cache boolean := true;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;
    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

    -- 1. Date Logic
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE
        v_current_year := p_ano::int;
    END IF;
    v_previous_year := v_current_year - 1;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        v_ref_date := make_date(v_current_year, v_target_month, 1);
    ELSE
        IF v_current_year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
            v_ref_date := make_date(v_current_year, 12, 1);
        ELSE
             v_ref_date := date_trunc('month', CURRENT_DATE)::date;
        END IF;
    END IF;

    v_tri_end := (v_ref_date - interval '1 day')::date;
    v_tri_start := (v_ref_date - interval '3 months')::date;

    -- 2. Build FILTERS
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_use_cache := false;
        v_where_raw := v_where_raw || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND filial = ANY(%L) ', p_filial);
        v_where_summary := v_where_summary || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND cidade = ANY(%L) ', p_cidade);
        v_where_summary := v_where_summary || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    -- Update: Map Name to Code for Summary
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
         v_where_summary := v_where_summary || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_raw := v_where_raw || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
         v_where_summary := v_where_summary || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_raw := v_where_raw || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
        v_where_summary := v_where_summary || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;

    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_summary := v_where_summary || format(' AND codfor = ANY(%L) ', p_fornecedor);

        -- Raw Logic (Complex OR/AND for mapped codes)
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                -- For Raw, we now check dim_produtos for description!
                -- This is tricky in dynamic SQL for complex ORs.
                -- Simplified approach: Join dim_produtos and check mapped description in query

                -- Construct conditions assuming query will have dp alias for dim_produtos
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(s.codfor = ''1119'' AND dp.descricao NOT ILIKE ''%TODDYNHO%'' AND dp.descricao NOT ILIKE ''%TODDY %'' AND dp.descricao NOT ILIKE ''%QUAKER%'' AND dp.descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;
            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('s.codfor = ANY(%L)', v_simple_codes));
            END IF;
            IF array_length(v_conditions, 1) > 0 THEN
                v_where_raw := v_where_raw || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
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
           v_where_summary := v_where_summary || ' AND (' || v_rede_condition || ') ';
           v_where_raw := v_where_raw || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Execute Queries

    IF v_use_cache THEN
        -- FAST PATH (Uses data_summary for totals)
        EXECUTE format('
            WITH
            chart_agg AS (
                SELECT
                    mes - 1 as m_idx,
                    ano as yr,
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano IN (%L, %L)
                GROUP BY 1, 2
            ),
            kpi_curr AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano = %L %s
            ),
            kpi_prev AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(peso) as peso,
                    SUM(COALESCE(caixas, 0)) as caixas
                FROM public.data_summary
                %s AND ano = %L %s
            ),
            kpi_tri AS (
                SELECT
                    SUM(vlvenda) / 3 as fat,
                    SUM(peso) / 3 as peso,
                    SUM(COALESCE(caixas, 0)) / 3 as caixas
                FROM public.data_summary
                %s AND make_date(ano, mes, 1) >= %L AND make_date(ano, mes, 1) <= %L
            ),
            -- Products Table (Updated to JOIN dim_produtos)
            prod_base AS (
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
                UNION ALL
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
            ),
            prod_agg AS (
                SELECT
                    produto,
                    MAX(descricao) as descricao,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                    SUM(vlvenda) as faturamento,
                    SUM(totpesoliq) as peso
                FROM prod_base
                GROUP BY 1
                ORDER BY caixas DESC
                LIMIT 50
            )
            SELECT
                (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas)) FROM chart_agg),
                (SELECT row_to_json(c) FROM kpi_curr c),
                (SELECT row_to_json(p) FROM kpi_prev p),
                (SELECT row_to_json(t) FROM kpi_tri t),
                (SELECT json_agg(pa) FROM prod_agg pa)
        ',
        v_where_summary, v_current_year, v_previous_year, -- Chart
        v_where_summary, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Curr
        v_where_summary, v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Prev
        v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), -- KPI Tri
        v_where_raw, v_current_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- Prod
        v_where_raw, v_current_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END  -- Prod
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    ELSE
        -- SLOW PATH (Full Raw Data with dim_produtos join)
        EXECUTE format('
            WITH base_data AS (
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
                UNION ALL
                SELECT s.dtped, s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao
                FROM public.data_history s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND s.dtped >= make_date(%L, 1, 1)
            ),
            chart_agg AS (
                SELECT
                    EXTRACT(MONTH FROM dtped)::int - 1 as m_idx,
                    EXTRACT(YEAR FROM dtped)::int as yr,
                    SUM(vlvenda) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) IN (%L, %L)
                GROUP BY 1, 2
            ),
            kpi_curr AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
            ),
            kpi_prev AS (
                SELECT
                    SUM(vlvenda) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
            ),
            kpi_tri AS (
                SELECT
                    SUM(vlvenda) / 3 as fat,
                    SUM(totpesoliq) / 3 as peso,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) / 3 as caixas
                FROM base_data
                WHERE dtped >= %L AND dtped <= %L
            ),
            prod_agg AS (
                SELECT
                    produto,
                    MAX(descricao) as descricao,
                    SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                    SUM(vlvenda) as faturamento,
                    SUM(totpesoliq) as peso
                FROM base_data
                WHERE EXTRACT(YEAR FROM dtped) = %L %s
                GROUP BY 1
                ORDER BY caixas DESC
                LIMIT 50
            )
            SELECT
                (SELECT json_agg(json_build_object(''month_index'', m_idx, ''year'', yr, ''faturamento'', fat, ''peso'', peso, ''caixas'', caixas)) FROM chart_agg),
                (SELECT row_to_json(c) FROM kpi_curr c),
                (SELECT row_to_json(p) FROM kpi_prev p),
                (SELECT row_to_json(t) FROM kpi_tri t),
                (SELECT json_agg(pa) FROM prod_agg pa)
        ',
        v_where_raw, v_previous_year,
        v_where_raw, v_previous_year,
        v_current_year, v_previous_year,
        v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END,
        v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END,
        v_tri_start, v_tri_end,
        v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;
    END IF;

    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json)
    );
END;
$$;

-- F. Branch Comparison (Update to use Codes)
CREATE OR REPLACE FUNCTION get_branch_comparison_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_produto text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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

    -- Rede Logic
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';

    -- 1. Date & Trend Setup
    IF p_ano IS NULL OR p_ano = 'todos' OR p_ano = '' THEN
        SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_current_year FROM public.data_summary;
    ELSE v_current_year := p_ano::int; END IF;

    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_target_month := p_mes::int + 1;
    ELSE SELECT COALESCE(MAX(mes), 12) INTO v_target_month FROM public.data_summary WHERE ano = v_current_year; END IF;

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

    -- UPDATE: Codes
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor); END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda); END IF;

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
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
       END IF;
    END IF;

    -- 3. Execute
    v_sql := '
    WITH agg_filial AS (
        SELECT
            filial,
            mes,
            SUM(CASE WHEN ($1 IS NOT NULL AND array_length($1, 1) > 0) THEN vlvenda WHEN tipovenda IN (''1'', ''9'') THEN vlvenda ELSE 0 END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao
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
                ''peso'', peso,
                ''bonificacao'', bonificacao
            ) ORDER BY mes),
            ''trend_allowed'', $2,
            ''trend_data'', CASE WHEN $2 THEN
                 (SELECT json_build_object(''month_index'', mes - 1, ''faturamento'', faturamento * $3, ''peso'', peso * $3, ''bonificacao'', bonificacao * $3)
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

-- G. City View Data (Update filtering for codes)
CREATE OR REPLACE FUNCTION get_city_view_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null,
    p_page int default 0,
    p_limit int default 50,
    p_inactive_page int default 0,
    p_inactive_limit int default 50
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL work_mem = '64MB';
    SET LOCAL statement_timeout = '120s';

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
    -- UPDATE: Codes
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;

    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where := v_where || format(' AND codfor = ANY(%L) ', p_fornecedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
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
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
           v_where_clients := v_where_clients || ' AND (' || v_rede_condition || ') ';
       END IF;
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
        json_build_object(
            ''cols'', json_build_array(''Código'', ''fantasia'', ''razaoSocial'', ''totalFaturamento'', ''cidade'', ''bairro'', ''rca1''),
            ''rows'', COALESCE(json_agg(json_build_array(pc.codcli, pc.fantasia, pc.razaosocial, pc.total_fat, pc.cidade, pc.bairro, pc.rca1) ORDER BY pc.total_fat DESC), ''[]''::json)
        )
    FROM paginated_clients pc;
    ';

    EXECUTE v_sql INTO v_total_active_count, v_active_clients USING p_limit, p_page;

    -- INACTIVE CLIENTS QUERY
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
        json_build_object(
            ''cols'', json_build_array(''Código'', ''fantasia'', ''razaoSocial'', ''cidade'', ''bairro'', ''ultimaCompra'', ''rca1''),
            ''rows'', COALESCE(json_agg(json_build_array(pi.codigo_cliente, pi.fantasia, pi.razaosocial, pi.cidade, pi.bairro, pi.ultimacompra, pi.rca1) ORDER BY pi.ultimacompra DESC NULLS LAST), ''[]''::json)
        )
    FROM paginated_inactive pi;
    ';

    EXECUTE v_sql INTO v_total_inactive_count, v_inactive_clients USING p_inactive_limit, p_inactive_page;

    RETURN json_build_object(
        'active_clients', v_active_clients,
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', v_inactive_clients,
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
END;
$$;
