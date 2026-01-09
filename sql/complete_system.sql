
-- ==============================================================================
-- UNIFIED DATABASE SETUP & OPTIMIZED SYSTEM SCRIPT v3
-- Contains: Tables, Dynamic SQL, Partial Indexes, Summary Logic, RLS, Trends, Caching
-- ==============================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ==============================================================================
-- 1. BASE TABLES
-- ==============================================================================

-- Sales Detailed (Current Month/Recent)
create table if not exists public.data_detailed (
  id uuid default uuid_generate_v4 () primary key,
  pedido text,
  nome text,
  superv text,
  produto text,
  descricao text,
  fornecedor text,
  observacaofor text,
  codfor text,
  codusur text,
  codcli text,
  cliente_nome text,
  cidade text,
  bairro text,
  qtvenda numeric,
  codsupervisor text,
  vlvenda numeric,
  vlbonific numeric,
  vldevolucao numeric,
  totpesoliq numeric,
  dtped timestamp with time zone,
  dtsaida timestamp with time zone,
  posicao text,
  estoqueunit numeric,
  qtvenda_embalagem_master numeric,
  tipovenda text,
  filial text,
  created_at timestamp with time zone default now()
);

-- Sales History
create table if not exists public.data_history (
  id uuid default uuid_generate_v4 () primary key,
  pedido text,
  nome text,
  superv text,
  produto text,
  descricao text,
  fornecedor text,
  observacaofor text,
  codfor text,
  codusur text,
  codcli text,
  cliente_nome text,
  cidade text,
  bairro text,
  qtvenda numeric,
  codsupervisor text,
  vlvenda numeric,
  vlbonific numeric,
  vldevolucao numeric,
  totpesoliq numeric,
  dtped timestamp with time zone,
  dtsaida timestamp with time zone,
  posicao text,
  estoqueunit numeric,
  qtvenda_embalagem_master numeric,
  tipovenda text,
  filial text,
  created_at timestamp with time zone default now()
);

-- Clients (Optimized: No RCA2)
create table if not exists public.data_clients (
  id uuid default uuid_generate_v4 () primary key,
  codigo_cliente text unique,
  rca1 text,
  cidade text,
  nomecliente text,
  bairro text,
  razaosocial text,
  fantasia text,
  ramo text,
  ultimacompra timestamp with time zone,
  bloqueio text,
  created_at timestamp with time zone default now()
);

-- Remove RCA 2 Column if it exists (for migration support)
DO $$
BEGIN
    -- Check if column exists AND if it is a BASE TABLE (not a view)
    -- This prevents error 42P16 if data_clients has been converted to a view
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns c
        JOIN information_schema.tables t ON c.table_name = t.table_name AND c.table_schema = t.table_schema
        WHERE c.table_schema = 'public'
          AND c.table_name = 'data_clients'
          AND c.column_name = 'rca2'
          AND t.table_type = 'BASE TABLE'
    ) THEN
        BEGIN
            EXECUTE 'ALTER TABLE public.data_clients DROP COLUMN rca2';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not drop column rca2 from public.data_clients: %', SQLERRM;
        END;
    END IF;
END $$;

-- Add mix_details column if it does not exist (Schema Migration)
-- Holidays Table
create table if not exists public.data_holidays (
    date date PRIMARY KEY,
    description text
);

-- Profiles
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  status text default 'pendente', -- pendente, aprovado, bloqueado
  role text default 'user',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Config City Branches (Mapping)
CREATE TABLE IF NOT EXISTS public.config_city_branches (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    cidade text NOT NULL UNIQUE,
    filial text, 
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);

-- Unified View
create or replace view public.all_sales as
select * from public.data_detailed
union all
select * from public.data_history;

-- Summary Table (Pre-Aggregated for Dashboard Speed)
-- Includes mix_produtos array for denormalized counting
DROP TABLE IF EXISTS public.data_summary CASCADE;
create table if not exists public.data_summary (
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

-- Add mix_details column if it does not exist (Schema Migration)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_summary' AND column_name = 'mix_details') THEN
        ALTER TABLE public.data_summary ADD COLUMN mix_details jsonb;
    END IF;
END $$;

-- Add pre_mix_count and pre_positivacao_val if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_summary' AND column_name = 'pre_mix_count') THEN
        ALTER TABLE public.data_summary ADD COLUMN pre_mix_count int DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_summary' AND column_name = 'pre_positivacao_val') THEN
        ALTER TABLE public.data_summary ADD COLUMN pre_positivacao_val int DEFAULT 0;
    END IF;
END $$;

-- Cache Table (For Filter Dropdowns)
DROP TABLE IF EXISTS public.cache_filters CASCADE;
create table if not exists public.cache_filters (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    filial text,
    cidade text,
    superv text,
    nome text,
    codfor text,
    fornecedor text,
    tipovenda text,
    ano int,
    mes int,
    created_at timestamp with time zone default now()
);

-- ==============================================================================
-- 2. OPTIMIZED INDEXES (Targeted Partial Indexes)
-- ==============================================================================

-- Drop old monolithic indexes if they exist
DROP INDEX IF EXISTS public.idx_summary_main;
DROP INDEX IF EXISTS public.idx_cache_filters_fornecedor_col;
DROP INDEX IF EXISTS public.idx_detailed_cidade_btree;
DROP INDEX IF EXISTS public.idx_detailed_filial_btree;
DROP INDEX IF EXISTS public.idx_detailed_nome_btree;
DROP INDEX IF EXISTS public.idx_detailed_superv_btree;
DROP INDEX IF EXISTS public.idx_history_cidade_btree;
DROP INDEX IF EXISTS public.idx_history_filial_btree;
DROP INDEX IF EXISTS public.idx_history_nome_btree;
DROP INDEX IF EXISTS public.idx_history_superv_btree;
DROP INDEX IF EXISTS idx_cache_filters_superv_composite;
DROP INDEX IF EXISTS idx_cache_filters_nome_composite;
DROP INDEX IF EXISTS idx_cache_filters_cidade_composite;
DROP INDEX IF EXISTS idx_detailed_dtped_composite;
DROP INDEX IF EXISTS idx_history_dtped_composite;

-- Sales Table Indexes
CREATE INDEX idx_detailed_dtped_composite ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor);
CREATE INDEX idx_history_dtped_composite ON public.data_history (dtped, filial, cidade, superv, nome, codfor);
CREATE INDEX IF NOT EXISTS idx_detailed_dtped_desc ON public.data_detailed(dtped DESC);
CREATE INDEX IF NOT EXISTS idx_detailed_codfor_dtped ON public.data_detailed (codfor, dtped);
CREATE INDEX IF NOT EXISTS idx_history_codfor_dtped ON public.data_history (codfor, dtped);
CREATE INDEX IF NOT EXISTS idx_clients_cidade ON public.data_clients(cidade);

-- Summary Table Targeted Indexes (For Dynamic SQL)
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_superv ON public.data_summary (ano, mes, superv);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_nome ON public.data_summary (ano, mes, nome); -- Vendedor
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_cidade ON public.data_summary (ano, mes, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_filial ON public.data_summary (ano, mes, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codfor ON public.data_summary (ano, mes, codfor);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_tipovenda ON public.data_summary (ano, mes, tipovenda);
CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codcli ON public.data_summary (ano, mes, codcli);

-- Cache Filters Indexes
CREATE INDEX idx_cache_filters_composite ON public.cache_filters (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);
CREATE INDEX IF NOT EXISTS idx_cache_filters_superv_lookup ON public.cache_filters (filial, cidade, ano, superv);
CREATE INDEX IF NOT EXISTS idx_cache_filters_nome_lookup ON public.cache_filters (filial, cidade, superv, ano, nome);
CREATE INDEX IF NOT EXISTS idx_cache_filters_cidade_lookup ON public.cache_filters (filial, ano, cidade);
CREATE INDEX IF NOT EXISTS idx_cache_ano_superv ON public.cache_filters (ano, superv);
CREATE INDEX IF NOT EXISTS idx_cache_ano_nome ON public.cache_filters (ano, nome);
CREATE INDEX IF NOT EXISTS idx_cache_ano_cidade ON public.cache_filters (ano, cidade);
CREATE INDEX IF NOT EXISTS idx_cache_ano_filial ON public.cache_filters (ano, filial);
CREATE INDEX IF NOT EXISTS idx_cache_ano_tipovenda ON public.cache_filters (ano, tipovenda);
CREATE INDEX IF NOT EXISTS idx_cache_ano_fornecedor ON public.cache_filters (ano, fornecedor, codfor);

-- ==============================================================================
-- 3. SECURITY & RLS POLICIES
-- ==============================================================================

-- Helper Functions
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND role = 'adm');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_approved() RETURNS boolean AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND status = 'aprovado');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE public.data_detailed ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cache_filters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.config_city_branches ENABLE ROW LEVEL SECURITY;

-- Clean up Insecure Policies
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles', 'data_summary', 'cache_filters', 'data_holidays', 'config_city_branches')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Delete Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "All Access Admin" ON public.%I;', t);
    END LOOP;
END $$;

-- Define Secure Policies

-- Profiles
DROP POLICY IF EXISTS "Profiles Visibility" ON public.profiles;
DROP POLICY IF EXISTS "Profiles Select" ON public.profiles;
CREATE POLICY "Profiles Select" ON public.profiles FOR SELECT USING ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles Insert" ON public.profiles;
CREATE POLICY "Profiles Insert" ON public.profiles FOR INSERT WITH CHECK ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles Update" ON public.profiles;
CREATE POLICY "Profiles Update" ON public.profiles FOR UPDATE USING ((select auth.uid()) = id OR public.is_admin()) WITH CHECK ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Admin Manage Profiles" ON public.profiles;
DROP POLICY IF EXISTS "Profiles Delete" ON public.profiles;
CREATE POLICY "Profiles Delete" ON public.profiles FOR DELETE USING (public.is_admin());

-- Config City Branches
CREATE POLICY "Read Access Approved" ON public.config_city_branches FOR SELECT USING (public.is_approved());
CREATE POLICY "All Access Admin" ON public.config_city_branches FOR ALL USING (public.is_admin());

-- Holidays Policies
CREATE POLICY "Read Access Approved" ON public.data_holidays FOR SELECT USING (public.is_approved());
CREATE POLICY "Write Access Admin" ON public.data_holidays FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "Delete Access Admin" ON public.data_holidays FOR DELETE USING (public.is_admin());

-- Data Tables (Detailed, History, Clients, Summary, Cache)
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'cache_filters')
    LOOP
        -- Read: Approved Users
        EXECUTE format('CREATE POLICY "Read Access Approved" ON public.%I FOR SELECT USING (public.is_approved());', t);
        -- Write: Admins Only
        EXECUTE format('CREATE POLICY "Write Access Admin" ON public.%I FOR INSERT WITH CHECK (public.is_admin());', t);
        EXECUTE format('CREATE POLICY "Update Access Admin" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());', t);
        EXECUTE format('CREATE POLICY "Delete Access Admin" ON public.%I FOR DELETE USING (public.is_admin());', t);
    END LOOP;
END $$;

-- ==============================================================================
-- 4. RPCS & FUNCTIONS (LOGIC)
-- ==============================================================================

-- Clear Data Function
CREATE OR REPLACE FUNCTION clear_all_data()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM public.data_detailed;
    DELETE FROM public.data_history;
    DELETE FROM public.data_clients;
    -- Also clear derived tables
    TRUNCATE TABLE public.data_summary;
    TRUNCATE TABLE public.cache_filters;
END;
$$;

-- Safe Truncate Function
CREATE OR REPLACE FUNCTION public.truncate_table(table_name text)
RETURNS void AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso negado.'; END IF;
  IF table_name NOT IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'cache_filters') THEN RAISE EXCEPTION 'Tabela inválida.'; END IF;
  EXECUTE format('TRUNCATE TABLE public.%I;', table_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.truncate_table(text) TO authenticated;

-- Refresh Filters Cache Function
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';
    
    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes)
    SELECT DISTINCT 
        t.filial, 
        COALESCE(t.cidade, c.cidade) as cidade, 
        t.superv, 
        COALESCE(t.nome, c.nomecliente) as nome, 
        t.codfor, 
        t.fornecedor, 
        t.tipovenda, 
        t.yr, 
        t.mth
    FROM (
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente;
END;
$$;

-- Refresh Summary Cache Function (Optimized with Mix Products Array)
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;
    
    -- Inserção OTIMIZADA: Já calcula se houve positivação e contagem de mix
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, 
        vlvenda, peso, bonificacao, devolucao, 
        mix_produtos, mix_details,
        pre_mix_count, pre_positivacao_val
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto 
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto 
        FROM public.data_history
    ),
    augmented_data AS (
        SELECT 
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            s.filial, 
            COALESCE(s.cidade, c.cidade) as cidade, 
            s.superv, 
            COALESCE(s.nome, c.nomecliente) as nome, 
            s.codfor, 
            s.tipovenda, 
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
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
        -- CÁLCULOS PRÉVIOS AQUI:
        (SELECT COUNT(*) FROM jsonb_each_text(json_prod) WHERE (value)::numeric >= 1 AND codfor IN ('707', '708')) as mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc
    FROM client_agg;
    
    CLUSTER public.data_summary USING idx_summary_ano_mes_filial;
    ANALYZE public.data_summary;
END;
$$;

-- Refresh Cache & Summary Function (Legacy Wrapper)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM refresh_cache_filters();
    PERFORM refresh_cache_summary();
END;
$$;

-- Database Optimization Function (Rebuilds Targeted Indexes)
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

    -- Drop heavy indexes if they exist
    DROP INDEX IF EXISTS public.idx_summary_main;

    -- Recreate targeted optimized indexes
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_superv ON public.data_summary (ano, mes, superv);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_nome ON public.data_summary (ano, mes, nome);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_cidade ON public.data_summary (ano, mes, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_filial ON public.data_summary (ano, mes, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codfor ON public.data_summary (ano, mes, codfor);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_tipovenda ON public.data_summary (ano, mes, tipovenda);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_mes_codcli ON public.data_summary (ano, mes, codcli);
    
    RETURN 'Banco de dados otimizado com sucesso! Índices reconstruídos.';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erro ao otimizar banco: ' || SQLERRM;
END;
$$;

-- Toggle Holiday RPC
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

-- Helper: Calculate Working Days
CREATE OR REPLACE FUNCTION calc_working_days(start_date date, end_date date)
RETURNS int
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    days int;
BEGIN
    SELECT COUNT(*)
    INTO days
    FROM generate_series(start_date, end_date, '1 day'::interval) AS d
    WHERE EXTRACT(ISODOW FROM d) < 6 -- Mon-Fri (1-5)
      AND NOT EXISTS (SELECT 1 FROM public.data_holidays h WHERE h.date = d::date);
    
    RETURN days;
END;
$$;

-- Get Data Version (Cache Invalidation)
CREATE OR REPLACE FUNCTION get_data_version()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_update timestamp with time zone;
BEGIN
    SELECT MAX(created_at) INTO v_last_update FROM public.data_summary;
    IF v_last_update IS NULL THEN RETURN '1970-01-01 00:00:00+00'; END IF;
    RETURN v_last_update::text;
END;
$$;

-- Get Main Dashboard Data (Dynamic SQL, Parallelism, Pre-Aggregation)
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
    v_where_clause text := '';
    v_result json;
    
    -- Execution Context
    v_kpi_clients_attended int;
    v_kpi_clients_base int;
    v_monthly_chart_current json;
    v_monthly_chart_previous json;
    v_curr_month_idx int;
BEGIN
    -- Configurações de Memória para esta Query Específica
    SET LOCAL work_mem = '64MB'; -- Aumenta memória para ordenação
    SET LOCAL statement_timeout = '15s'; -- Fail fast se travar

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

    -- 2. Trend Logic Calculation (Mantida igual)
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
    -- Importante: Como usamos SECURITY DEFINER, verifique se a lógica de usuário aprovado se aplica aqui se necessário
    -- Mas como os filtros vêm do frontend, assumimos que a UI já restringiu o que o user pode pedir
    
    v_where_clause := 'WHERE ano IN ($1, $2) ';
    
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND filial = ANY($3) ';
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND cidade = ANY($4) ';
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND superv = ANY($5) ';
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND nome = ANY($6) ';
    END IF;
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND codfor = ANY($7) ';
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_clause := v_where_clause || ' AND tipovenda = ANY($8) ';
    END IF;

    -- 4. Execute Main Aggregation Query (VERSÃO OTIMIZADA)
    -- Removemos todas as subqueries complexas (mix_raw_data, monthly_mix_stats, etc)
    v_sql := '
    WITH filtered_summary AS (
        SELECT 
            ano, mes, codcli, vlvenda, peso, bonificacao, devolucao, tipovenda, pre_mix_count, pre_positivacao_val
        FROM public.data_summary
        ' || v_where_clause || '
    ),
    agg_data AS (
        SELECT
            ano,
            mes,
            -- Agregação simples e direta
            SUM(CASE 
                WHEN ($8 IS NOT NULL AND array_length($8, 1) > 0) THEN vlvenda
                WHEN tipovenda IN (''1'', ''9'') THEN vlvenda 
                ELSE 0 
            END) as faturamento,
            SUM(peso) as peso,
            SUM(bonificacao) as bonificacao,
            SUM(devolucao) as devolucao,
            -- Positivação usando a coluna pré-calculada
            COUNT(DISTINCT CASE WHEN pre_positivacao_val = 1 THEN codcli END) as positivacao_count,
            -- Mix pré-calculado (Respeitando regra de Venda/Venda Futura se filtro não for especificado)
            SUM(CASE 
                WHEN ($8 IS NOT NULL AND array_length($8, 1) > 0) THEN pre_mix_count
                WHEN tipovenda IN (''1'', ''9'') THEN pre_mix_count 
                ELSE 0 
            END) as total_mix_sum,
            COUNT(DISTINCT CASE 
                WHEN ($8 IS NOT NULL AND array_length($8, 1) > 0) AND pre_mix_count > 0 THEN codcli 
                WHEN tipovenda IN (''1'', ''9'') AND pre_mix_count > 0 THEN codcli 
                ELSE NULL 
            END) as mix_client_count
        FROM filtered_summary
        GROUP BY 1, 2
    ),
    kpi_active_count AS (
        SELECT COUNT(DISTINCT codcli) as val
        FROM filtered_summary 
        WHERE ano = $1 AND mes = $9 AND pre_positivacao_val = 1
    ),
    kpi_base_count AS (
        SELECT COUNT(*) as val FROM public.data_clients c 
        WHERE c.bloqueio != ''S'' 
        AND ($4 IS NULL OR array_length($4, 1) IS NULL OR c.cidade = ANY($4))
    )
    SELECT
        (SELECT val FROM kpi_active_count),
        (SELECT val FROM kpi_base_count),
        -- Gerar JSON diretamente
        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1, 
            ''faturamento'', a.faturamento, 
            ''peso'', a.peso, 
            ''bonificacao'', a.bonificacao, 
            ''devolucao'', a.devolucao, 
            ''positivacao'', a.positivacao_count, 
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END, 
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $1), ''[]''::json),
        
        COALESCE(json_agg(json_build_object(
            ''month_index'', a.mes - 1, 
            ''faturamento'', a.faturamento, 
            ''peso'', a.peso, 
            ''bonificacao'', a.bonificacao, 
            ''devolucao'', a.devolucao, 
            ''positivacao'', a.positivacao_count, 
            ''mix_pdv'', CASE WHEN a.mix_client_count > 0 THEN a.total_mix_sum::numeric / a.mix_client_count ELSE 0 END, 
            ''ticket_medio'', CASE WHEN a.positivacao_count > 0 THEN a.faturamento / a.positivacao_count ELSE 0 END
        ) ORDER BY a.mes) FILTER (WHERE a.ano = $2), ''[]''::json)
    FROM agg_data a
    ';

    EXECUTE v_sql 
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    USING v_current_year, v_previous_year, p_filial, p_cidade, p_supervisor, p_vendedor, p_fornecedor, p_tipovenda, v_target_month;

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

-- Get Dashboard Filters (Split Queries for Speed)
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
BEGIN
    SET LOCAL statement_timeout = '300s';

    IF p_ano IS NOT NULL AND p_ano != '' AND p_ano != 'todos' THEN
        v_filter_year := p_ano::int;
    ELSE
        IF p_ano = 'todos' THEN v_filter_year := NULL; 
        ELSE
            SELECT COALESCE(MAX(ano), EXTRACT(YEAR FROM CURRENT_DATE)::int) INTO v_filter_year FROM public.cache_filters;
        END IF;
    END IF;
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN v_filter_month := p_mes::int + 1; END IF;

    -- 1. Supervisors
    SELECT ARRAY(SELECT DISTINCT superv FROM public.cache_filters WHERE 
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND superv IS NOT NULL AND superv != '' AND superv != 'null'
        ORDER BY superv
    ) INTO v_supervisors;

    -- 2. Vendedores
    SELECT ARRAY(SELECT DISTINCT nome FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND nome IS NOT NULL AND nome != '' AND nome != 'null'
        ORDER BY nome
    ) INTO v_vendedores;

    -- 3. Cidades
    SELECT ARRAY(SELECT DISTINCT cidade FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND cidade IS NOT NULL AND cidade != '' AND cidade != 'null'
        ORDER BY cidade
    ) INTO v_cidades;

    -- 4. Filiais
    SELECT ARRAY(SELECT DISTINCT filial FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND filial IS NOT NULL AND filial != '' AND filial != 'null'
        ORDER BY filial
    ) INTO v_filiais;

    -- 5. Tipos de Venda
    SELECT ARRAY(SELECT DISTINCT tipovenda FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND tipovenda IS NOT NULL AND tipovenda != '' AND tipovenda != 'null'
        ORDER BY tipovenda
    ) INTO v_tipos_venda;

    -- 6. Fornecedores
    SELECT json_agg(json_build_object('cod', codfor, 'name', CASE WHEN codfor = '707' THEN 'Extrusados' WHEN codfor = '708' THEN 'Ñ Extrusados' WHEN codfor = '752' THEN 'Torcida' WHEN codfor = '1119' THEN 'Foods' ELSE fornecedor END) ORDER BY CASE WHEN codfor = '707' THEN 'Extrusados' WHEN codfor = '708' THEN 'Ñ Extrusados' WHEN codfor = '752' THEN 'Torcida' WHEN codfor = '1119' THEN 'Foods' ELSE fornecedor END) INTO v_fornecedores
    FROM (
        SELECT DISTINCT codfor, fornecedor FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND codfor IS NOT NULL
    ) t;

    -- 7. Anos
    SELECT ARRAY(SELECT DISTINCT ano FROM public.cache_filters WHERE
        (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        ORDER BY ano DESC
    ) INTO v_anos;

    RETURN json_build_object('supervisors', COALESCE(v_supervisors, '{}'), 'vendedores', COALESCE(v_vendedores, '{}'), 'fornecedores', COALESCE(v_fornecedores, '[]'::json), 'cidades', COALESCE(v_cidades, '{}'), 'filiais', COALESCE(v_filiais, '{}'), 'anos', COALESCE(v_anos, '{}'), 'tipos_venda', COALESCE(v_tipos_venda, '{}'));
END;
$$;

-- Function: Get City View (Paginated for both Active and Inactive, No RCA2)
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

-- ==============================================================================
-- 5. INITIALIZATION (Populate City Mapping + Refresh)
-- ==============================================================================

-- Populate City/Branch Map from History (Idempotent)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        WITH all_sales AS (
            SELECT cidade, filial, dtped FROM public.data_detailed
            UNION ALL
            SELECT cidade, filial, dtped FROM public.data_history
        ),
        ranked_sales AS (
            SELECT
                cidade,
                filial,
                ROW_NUMBER() OVER (PARTITION BY cidade ORDER BY dtped DESC) as rn
            FROM all_sales
            WHERE cidade IS NOT NULL AND cidade != '' AND filial IS NOT NULL
        )
        SELECT DISTINCT cidade, filial
        FROM ranked_sales
        WHERE rn = 1
    LOOP
        INSERT INTO public.config_city_branches (cidade, filial)
        VALUES (r.cidade, r.filial)
        ON CONFLICT (cidade) DO NOTHING;
    END LOOP;
END $$;

-- Refresh Cache to apply updates
-- Refresh Cache to apply updates (Populates both Summary and Filters for Dropdowns)
-- SELECT refresh_dashboard_cache(); -- Moved to refresh_data.sql
