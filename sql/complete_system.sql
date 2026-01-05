
-- ==============================================================================
-- UNIFIED DATABASE SETUP & MIGRATION SCRIPT
-- Contains: Tables, Optimized Indexes, Summary Tables, RLS Policies, and RPCs
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

-- Clients
create table if not exists public.data_clients (
  id uuid default uuid_generate_v4 () primary key,
  codigo_cliente text unique,
  rca1 text,
  rca2 text,
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

-- Profiles
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  status text default 'pendente', -- pendente, aprovado, bloqueado
  role text default 'user',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Unified View
create or replace view public.all_sales as
select * from public.data_detailed
union all
select * from public.data_history;

-- Summary Table (Pre-Aggregated for Dashboard Speed)
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
    created_at timestamp with time zone default now()
);

-- Cache Table (For Filter Dropdowns)
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
-- 2. OPTIMIZED INDEXES
-- ==============================================================================

-- Clean up duplicate/old indexes
DROP INDEX IF EXISTS public.idx_cache_filters_fornecedor_col;
DROP INDEX IF EXISTS public.idx_detailed_cidade_btree;
DROP INDEX IF EXISTS public.idx_detailed_filial_btree;
DROP INDEX IF EXISTS public.idx_detailed_nome_btree;
DROP INDEX IF EXISTS public.idx_detailed_superv_btree;
DROP INDEX IF EXISTS public.idx_history_cidade_btree;
DROP INDEX IF EXISTS public.idx_history_filial_btree;
DROP INDEX IF EXISTS public.idx_history_nome_btree;
DROP INDEX IF EXISTS public.idx_history_superv_btree;
DROP INDEX IF EXISTS idx_cache_filters_composite;
DROP INDEX IF EXISTS idx_cache_filters_superv_composite;
DROP INDEX IF EXISTS idx_cache_filters_nome_composite;
DROP INDEX IF EXISTS idx_cache_filters_cidade_composite;
DROP INDEX IF EXISTS idx_detailed_dtped_composite;
DROP INDEX IF EXISTS idx_history_dtped_composite;

-- Sales Table Indexes (Covering for KPI Base Clients & General Lookups)
CREATE INDEX idx_detailed_dtped_composite ON public.data_detailed (dtped, filial, cidade, superv, nome, codfor) INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);
CREATE INDEX idx_history_dtped_composite ON public.data_history (dtped, filial, cidade, superv, nome, codfor) INCLUDE (vlvenda, vldevolucao, totpesoliq, vlbonific, codcli, codusur, tipovenda);

-- Summary Table Index (For Main Dashboard)
CREATE INDEX idx_summary_main ON public.data_summary (ano, mes, filial, cidade, superv, nome, codfor, tipovenda) INCLUDE (vlvenda, peso, bonificacao, devolucao, codcli);

-- Cache Filters Indexes (For Dropdowns)
CREATE INDEX idx_cache_filters_composite ON public.cache_filters (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);
-- Specialized lookup indexes for specific dropdowns (Split Queries)
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

-- Clean up Insecure Policies
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles', 'data_summary', 'cache_filters')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
    END LOOP;
END $$;

-- Define Secure Policies

-- Profiles
DROP POLICY IF EXISTS "Profiles Visibility" ON public.profiles;
CREATE POLICY "Profiles Visibility" ON public.profiles FOR SELECT USING ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING ((select auth.uid()) = id) WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Admin Manage Profiles" ON public.profiles;
CREATE POLICY "Admin Manage Profiles" ON public.profiles FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Data Tables (Detailed, History, Clients, Summary, Cache)
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'cache_filters')
    LOOP
        -- Read: Approved Users
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Read Access Approved" ON public.%I FOR SELECT USING (public.is_approved());', t);
        
        -- Write: Admins Only
        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Write Access Admin" ON public.%I FOR INSERT WITH CHECK (public.is_admin());', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Update Access Admin" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Delete Access Admin" ON public.%I;', t);
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

-- Refresh Cache & Summary Function (Optimized)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Refresh Filters Cache (Distinct Values)
    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes)
    SELECT DISTINCT 
        filial, cidade, superv, nome, codfor, fornecedor, tipovenda, yr, mth
    FROM (
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, 
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, superv, nome, codfor, fornecedor, tipovenda, 
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_history
    ) t;

    -- 2. Refresh Data Summary (Aggregated Metrics)
    TRUNCATE TABLE public.data_summary;
    INSERT INTO public.data_summary (ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, peso, bonificacao, devolucao)
    SELECT 
        EXTRACT(YEAR FROM dtped)::int,
        EXTRACT(MONTH FROM dtped)::int,
        filial, cidade, superv, nome, codfor, tipovenda, codcli,
        SUM(vlvenda),
        SUM(totpesoliq),
        SUM(vlbonific),
        SUM(COALESCE(vldevolucao, 0))
    FROM (
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, superv, nome, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao FROM public.data_history
    ) all_sales
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9;
END;
$$;

-- Get Main Dashboard Data (Using Summary Table)
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
BEGIN
    SET LOCAL statement_timeout = '60s';

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

    WITH agg_data AS (
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
            SUM(devolucao) as devolucao,
            COUNT(DISTINCT CASE WHEN vlvenda >= 1 THEN codcli END) as positivacao
        FROM public.data_summary
        WHERE ano IN (v_current_year, v_previous_year)
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        GROUP BY 1, 2
    ),
    kpi_active AS (
        SELECT COUNT(DISTINCT codcli) as val
        FROM public.data_summary
        WHERE ano = v_current_year AND mes = v_target_month
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
          AND vlvenda >= 1
    )
    SELECT
        (SELECT val FROM kpi_active),
        (SELECT COUNT(*) FROM public.data_clients c WHERE c.bloqueio != 'S' AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR c.cidade = ANY(p_cidade))),
        COALESCE(json_agg(json_build_object('month_index', mes - 1, 'faturamento', faturamento, 'peso', peso, 'bonificacao', bonificacao, 'devolucao', devolucao, 'positivacao', positivacao) ORDER BY mes) FILTER (WHERE ano = v_current_year), '[]'::json),
        COALESCE(json_agg(json_build_object('month_index', mes - 1, 'faturamento', faturamento, 'peso', peso, 'bonificacao', bonificacao, 'devolucao', devolucao, 'positivacao', positivacao) ORDER BY mes) FILTER (WHERE ano = v_previous_year), '[]'::json)
    INTO v_kpi_clients_attended, v_kpi_clients_base, v_monthly_chart_current, v_monthly_chart_previous
    FROM agg_data;

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
    SET LOCAL statement_timeout = '120s';

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

-- Function: Get City View (Keeping as is, it's generally fine, but could be optimized to use summary if needed. 
-- For now, relying on the new composite indexes on data tables)
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
    p_limit int default 50
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
          AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
          AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
          AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
          AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
          AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
          AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        GROUP BY codcli
        HAVING SUM(vlvenda) > 0
    ),
    count_cte AS (SELECT COUNT(*) as cnt FROM client_totals),
    paginated_clients AS (
        SELECT ct.codcli, ct.total_fat, c.fantasia, c.razaosocial, c.cidade, c.bairro, c.rca1, c.rca2
        FROM client_totals ct
        JOIN public.data_clients c ON c.codigo_cliente = ct.codcli
        ORDER BY ct.total_fat DESC
        LIMIT p_limit OFFSET (p_page * p_limit)
    )
    SELECT (SELECT cnt FROM count_cte), json_agg(json_build_object('Código', pc.codcli, 'fantasia', pc.fantasia, 'razaoSocial', pc.razaosocial, 'totalFaturamento', pc.total_fat, 'cidade', pc.cidade, 'bairro', pc.bairro, 'rca1', pc.rca1, 'rca2', pc.rca2) ORDER BY pc.total_fat DESC) 
    INTO v_total_active_count, v_active_clients
    FROM paginated_clients pc;

    -- Inactive Clients (Optimized using Summary table for existence check)
    -- This is still heavy as it scans data_clients, but avoiding data_detailed scan is a win.
    SELECT json_agg(
        json_build_object('Código', c.codigo_cliente, 'fantasia', c.fantasia, 'razaoSocial', c.razaosocial, 'cidade', c.cidade, 'bairro', c.bairro, 'ultimaCompra', c.ultimacompra, 'rca1', c.rca1, 'rca2', c.rca2) 
        ORDER BY c.ultimacompra DESC NULLS LAST
    ) INTO v_inactive_clients
    FROM public.data_clients c
    WHERE c.bloqueio != 'S'
      AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR c.cidade = ANY(p_cidade))
      AND NOT EXISTS (
          SELECT 1 FROM public.data_summary s2
          WHERE s2.codcli = c.codigo_cliente
            AND s2.ano = v_current_year
            AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR s2.filial = ANY(p_filial))
            AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR s2.cidade = ANY(p_cidade))
            AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR s2.superv = ANY(p_supervisor))
            AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR s2.nome = ANY(p_vendedor))
            AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR s2.codfor = ANY(p_fornecedor))
            AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR s2.tipovenda = ANY(p_tipovenda))
      );

    v_result := json_build_object('active_clients', COALESCE(v_active_clients, '[]'::json), 'total_active_count', COALESCE(v_total_active_count, 0), 'inactive_clients', COALESCE(v_inactive_clients, '[]'::json));
    RETURN v_result;
END;
$$;


-- ==============================================================================
-- 5. INITIALIZATION (RUN LAST)
-- ==============================================================================
SELECT refresh_dashboard_cache();
