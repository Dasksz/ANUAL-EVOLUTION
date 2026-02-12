
-- ==============================================================================
-- UNIFIED DATABASE SETUP & OPTIMIZED SYSTEM SCRIPT (V2 - Storage Optimized)
-- Contains: Tables, Dynamic SQL, Partial Indexes, Summary Logic, RLS, Trends, Caching
-- Consolidates all previous SQL files into one master schema with storage optimizations.
-- ==============================================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ==============================================================================
-- 1. BASE TABLES (Optimized: Removed Text Columns)
-- ==============================================================================

-- Sales Detailed (Current Month/Recent)
create table if not exists public.data_detailed (
  id uuid default uuid_generate_v4 () primary key,
  pedido text,
  codusur text,
  codsupervisor text,
  produto text,
  -- descricao text, -- REMOVED (Storage Optimization)
  codfor text,
  -- observacaofor text, -- REMOVED (Storage Optimization)
  codcli text,
  -- cliente_nome text, -- REMOVED (Storage Optimization)
  cidade text,
  -- bairro text, -- REMOVED (Storage Optimization)
  qtvenda numeric,
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
  codusur text,
  codsupervisor text,
  produto text,
  -- descricao text, -- REMOVED (Storage Optimization)
  codfor text,
  -- observacaofor text, -- REMOVED (Storage Optimization)
  codcli text,
  -- cliente_nome text, -- REMOVED (Storage Optimization)
  cidade text,
  -- bairro text, -- REMOVED (Storage Optimization)
  qtvenda numeric,
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

-- Migration Helper: Drop columns if they exist (for existing databases)
DO $$
BEGIN
    -- Drop from data_detailed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'cliente_nome') THEN
        ALTER TABLE public.data_detailed DROP COLUMN cliente_nome CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'bairro') THEN
        ALTER TABLE public.data_detailed DROP COLUMN bairro CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'observacaofor') THEN
        ALTER TABLE public.data_detailed DROP COLUMN observacaofor CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'descricao') THEN
        ALTER TABLE public.data_detailed DROP COLUMN descricao CASCADE;
    END IF;

    -- Drop from data_history
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'cliente_nome') THEN
        ALTER TABLE public.data_history DROP COLUMN cliente_nome CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'bairro') THEN
        ALTER TABLE public.data_history DROP COLUMN bairro CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'observacaofor') THEN
        ALTER TABLE public.data_history DROP COLUMN observacaofor CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'descricao') THEN
        ALTER TABLE public.data_history DROP COLUMN descricao CASCADE;
    END IF;
END $$;

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
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_clients' AND column_name = 'rca2') THEN
        ALTER TABLE public.data_clients DROP COLUMN rca2;
    END IF;
END $$;

-- Add Ramo column if it does not exist (Schema Migration)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_clients' AND column_name = 'ramo') THEN
        ALTER TABLE public.data_clients ADD COLUMN ramo text;
    END IF;
END $$;

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

-- Dimension Tables
CREATE TABLE IF NOT EXISTS public.dim_supervisores (
    codigo text PRIMARY KEY,
    nome text
);
ALTER TABLE public.dim_supervisores ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.dim_vendedores (
    codigo text PRIMARY KEY,
    nome text
);
ALTER TABLE public.dim_vendedores ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.dim_fornecedores (
    codigo text PRIMARY KEY,
    nome text
);
ALTER TABLE public.dim_fornecedores ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.dim_produtos (
    codigo text PRIMARY KEY,
    descricao text,
    codfor text,
    mix_marca text,    -- NEW: Optimized Mix Logic
    mix_categoria text -- NEW: Optimized Mix Logic
);
ALTER TABLE public.dim_produtos ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'codfor') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN codfor text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'mix_marca') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN mix_marca text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dim_produtos' AND column_name = 'mix_categoria') THEN
        ALTER TABLE public.dim_produtos ADD COLUMN mix_categoria text;
    END IF;
END $$;

-- Unified View
DROP VIEW IF EXISTS public.all_sales CASCADE;
create or replace view public.all_sales with (security_invoker = true) as
select * from public.data_detailed
union all
select * from public.data_history;

-- Summary Table (Optimized: Uses Codes instead of Names)
DROP TABLE IF EXISTS public.data_summary CASCADE;
create table if not exists public.data_summary (
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
    pre_positivacao_val int DEFAULT 0, -- 1 se positivou, 0 se não
    ramo text, -- ADDED: Rede Filter
    caixas numeric DEFAULT 0,
    created_at timestamp with time zone default now()
);

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
    rede text, -- ADDED: Rede Filter
    created_at timestamp with time zone default now()
);

-- ==============================================================================
-- 2. OPTIMIZED INDEXES (Targeted Partial Indexes)
-- ==============================================================================

-- Sales Table Indexes
CREATE INDEX IF NOT EXISTS idx_detailed_dtped_composite ON public.data_detailed (dtped, filial, cidade, codsupervisor, codusur, codfor);
CREATE INDEX IF NOT EXISTS idx_history_dtped_composite ON public.data_history (dtped, filial, cidade, codsupervisor, codusur, codfor);
CREATE INDEX IF NOT EXISTS idx_detailed_dtped_desc ON public.data_detailed(dtped DESC);
CREATE INDEX IF NOT EXISTS idx_detailed_codfor_dtped ON public.data_detailed (codfor, dtped);
CREATE INDEX IF NOT EXISTS idx_history_codfor_dtped ON public.data_history (codfor, dtped);
CREATE INDEX IF NOT EXISTS idx_detailed_produto ON public.data_detailed (produto);
CREATE INDEX IF NOT EXISTS idx_history_produto ON public.data_history (produto);
CREATE INDEX IF NOT EXISTS idx_clients_cidade ON public.data_clients(cidade);
CREATE INDEX IF NOT EXISTS idx_clients_bloqueio_cidade ON public.data_clients (bloqueio, cidade);
CREATE INDEX IF NOT EXISTS idx_clients_ramo ON public.data_clients (ramo);
CREATE INDEX IF NOT EXISTS idx_clients_busca ON public.data_clients (codigo_cliente, rca1, cidade);

-- NEW OPTIMIZATION INDEXES
CREATE INDEX IF NOT EXISTS idx_dim_produtos_mix_marca ON public.dim_produtos (mix_marca);
CREATE INDEX IF NOT EXISTS idx_dim_produtos_mix_categoria ON public.dim_produtos (mix_categoria);
CREATE INDEX IF NOT EXISTS idx_data_clients_rede_lookup ON public.data_clients (codigo_cliente, ramo);

-- OPTIMIZATION FOR BOXES DASHBOARD (Product Table Speed)
-- Composite index (dtped, produto) to optimize range scans by date
CREATE INDEX IF NOT EXISTS idx_detailed_dtped_prod ON public.data_detailed (dtped, produto);
CREATE INDEX IF NOT EXISTS idx_history_dtped_prod ON public.data_history (dtped, produto);

-- Summary Table Targeted Indexes (For Dynamic SQL)
-- V2 Optimized Indexes (Codes)
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

-- Cache Filters Indexes
CREATE INDEX IF NOT EXISTS idx_cache_filters_composite ON public.cache_filters (ano, mes, filial, cidade, superv, nome, codfor, tipovenda);
CREATE INDEX IF NOT EXISTS idx_cache_filters_superv_lookup ON public.cache_filters (filial, cidade, ano, superv);
CREATE INDEX IF NOT EXISTS idx_cache_filters_nome_lookup ON public.cache_filters (filial, cidade, superv, ano, nome);
CREATE INDEX IF NOT EXISTS idx_cache_filters_cidade_lookup ON public.cache_filters (filial, ano, cidade);
CREATE INDEX IF NOT EXISTS idx_cache_ano_superv ON public.cache_filters (ano, superv);
CREATE INDEX IF NOT EXISTS idx_cache_ano_nome ON public.cache_filters (ano, nome);
CREATE INDEX IF NOT EXISTS idx_cache_ano_cidade ON public.cache_filters (ano, cidade);
CREATE INDEX IF NOT EXISTS idx_cache_ano_filial ON public.cache_filters (ano, filial);
CREATE INDEX IF NOT EXISTS idx_cache_ano_tipovenda ON public.cache_filters (ano, tipovenda);
CREATE INDEX IF NOT EXISTS idx_cache_ano_fornecedor ON public.cache_filters (ano, fornecedor, codfor);
CREATE INDEX IF NOT EXISTS idx_cache_filters_rede_lookup ON public.cache_filters (filial, cidade, superv, ano, rede);

-- ==============================================================================
-- 3. SECURITY & RLS POLICIES
-- ==============================================================================

-- Helper Functions
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
SET search_path = public
AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND role = 'adm');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_approved() RETURNS boolean
SET search_path = public
AS $$
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
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles', 'data_summary', 'cache_filters', 'data_holidays', 'config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Delete Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "All Access Admin" ON public.%I;', t);
        -- Drop obsolete policies causing performance warnings
        EXECUTE format('DROP POLICY IF EXISTS "Delete Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Insert Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access" ON public.%I;', t);
        
        -- New standardized policy names
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I;', t);
    END LOOP;
END $$;

-- Define Secure Policies

-- Profiles
DROP POLICY IF EXISTS "Profiles Select" ON public.profiles;
CREATE POLICY "Profiles Select" ON public.profiles FOR SELECT USING ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Profiles Insert" ON public.profiles;
CREATE POLICY "Profiles Insert" ON public.profiles FOR INSERT WITH CHECK ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Profiles Update" ON public.profiles;
CREATE POLICY "Profiles Update" ON public.profiles FOR UPDATE USING ((select auth.uid()) = id OR public.is_admin()) WITH CHECK ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS "Profiles Delete" ON public.profiles;
CREATE POLICY "Profiles Delete" ON public.profiles FOR DELETE USING (public.is_admin());

-- Config City Branches & Dimensions
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores', 'dim_produtos'])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Unified Read Access" ON public.%I FOR SELECT USING (public.is_admin() OR public.is_approved())', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Insert" ON public.%I FOR INSERT WITH CHECK (public.is_admin())', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Update" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin())', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Delete" ON public.%I FOR DELETE USING (public.is_admin())', t);
    END LOOP;
END $$;

-- Holidays Policies
DROP POLICY IF EXISTS "Unified Read Access" ON public.data_holidays;
CREATE POLICY "Unified Read Access" ON public.data_holidays FOR SELECT USING (public.is_approved());

DROP POLICY IF EXISTS "Admin Insert" ON public.data_holidays;
CREATE POLICY "Admin Insert" ON public.data_holidays FOR INSERT WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin Delete" ON public.data_holidays;
CREATE POLICY "Admin Delete" ON public.data_holidays FOR DELETE USING (public.is_admin());

-- Data Tables (Detailed, History, Clients, Summary, Cache)
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'cache_filters')
    LOOP
        -- Read: Approved Users
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Unified Read Access" ON public.%I FOR SELECT USING (public.is_approved());', t);
        
        -- Write: Admins Only
        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Insert" ON public.%I FOR INSERT WITH CHECK (public.is_admin());', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Update" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());', t);
        
        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Delete" ON public.%I FOR DELETE USING (public.is_admin());', t);
    END LOOP;
END $$;

-- ==============================================================================
-- 4. RPCS & FUNCTIONS (LOGIC)
-- ==============================================================================

-- Function to classify products based on description (Auto-Mix)
CREATE OR REPLACE FUNCTION classify_product_mix()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- Initialize as null
    NEW.mix_marca := NULL;
    NEW.mix_categoria := NULL;

    -- Brand Logic (Optimization: avoid ILIKE if possible, but description is unstructured)
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

    -- Category Logic
    IF NEW.mix_marca IN ('CHEETOS', 'DORITOS', 'FANDANGOS', 'RUFFLES', 'TORCIDA') THEN
        NEW.mix_categoria := 'SALTY';
    ELSIF NEW.mix_marca IN ('TODDYNHO', 'TODDY', 'QUAKER', 'KEROCOCO') THEN
        NEW.mix_categoria := 'FOODS';
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger to keep mix columns updated
DROP TRIGGER IF EXISTS trg_classify_products ON public.dim_produtos;
CREATE TRIGGER trg_classify_products
BEFORE INSERT OR UPDATE OF descricao ON public.dim_produtos
FOR EACH ROW
EXECUTE FUNCTION classify_product_mix();

-- Run classification on existing rows that are null (Migration)
UPDATE public.dim_produtos SET descricao = descricao WHERE mix_marca IS NULL;


-- Clear Data Function
CREATE OR REPLACE FUNCTION clear_all_data()
RETURNS void
LANGUAGE plpgsql
SET search_path = public
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
RETURNS void
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso negado.'; END IF;
  IF table_name NOT IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'cache_filters') THEN RAISE EXCEPTION 'Tabela inválida.'; END IF;
  EXECUTE format('TRUNCATE TABLE public.%I;', table_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.truncate_table(text) TO authenticated;

-- Refresh Filters Cache Function (Join dim_produtos for description)
-- REFRESH CACHE FUNCTIONS (Split for Timeout Optimization - Chunked by Year)

-- 1. Get Available Years
-- 1. Get Available Years (Optimized using Range)
CREATE OR REPLACE FUNCTION get_available_years()
RETURNS int[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    min_year int;
    max_year int;
    years int[];
BEGIN
    -- Get Min/Max from both tables efficiently using indexes
    SELECT 
        LEAST(
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_history)
        ),
        GREATEST(
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_history)
        )
    INTO min_year, max_year;

    -- Handle empty tables
    IF min_year IS NULL THEN 
        min_year := COALESCE(
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MIN(dtped))::int FROM public.data_history),
            EXTRACT(YEAR FROM CURRENT_DATE)::int
        );
    END IF;
    
    IF max_year IS NULL THEN
        max_year := COALESCE(
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_detailed),
            (SELECT EXTRACT(YEAR FROM MAX(dtped))::int FROM public.data_history),
            EXTRACT(YEAR FROM CURRENT_DATE)::int
        );
    END IF;

    -- Generate series
    SELECT array_agg(y ORDER BY y DESC) INTO years
    FROM generate_series(min_year, max_year) as y;
    
    RETURN years;
END;
$$;

-- 2. Refresh Summary for Specific Year (Idempotent)
CREATE OR REPLACE FUNCTION refresh_summary_year(p_year int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    -- Clear data for this year first (avoid duplicates)
    DELETE FROM public.data_summary WHERE ano = p_year;
    
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao, 
        pre_mix_count, pre_positivacao_val,
        ramo, caixas
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

-- 2.1. Refresh Summary for Specific Month (Granular for Timeout Avoidance)
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
        ramo, caixas
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
    
    -- No internal ANALYZE to keep chunks fast
END;
$$;

-- 3. Refresh Filters Cache (Optimized: Uses data_summary)
CREATE OR REPLACE FUNCTION refresh_cache_filters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';
    
    -- Ensure stats are up to date before complex joins
    ANALYZE public.data_summary;

    TRUNCATE TABLE public.cache_filters;
    INSERT INTO public.cache_filters (filial, cidade, superv, nome, codfor, fornecedor, tipovenda, ano, mes, rede)
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
        t.ramo as rede
    FROM public.data_summary t
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codusur = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo;
END;
$$;

-- 4. Refresh Dashboard Cache Wrapper (Looping version for manual use)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    r_year int;
    r_month int;
BEGIN
    -- 1. Truncate Main
    TRUNCATE TABLE public.data_summary;
    
    -- 2. Loop Years and Months
    FOR r_year IN SELECT y FROM unnest(get_available_years()) as y
    LOOP
        FOR r_month IN 1..12
        LOOP
            PERFORM refresh_summary_month(r_year, r_month);
        END LOOP;
    END LOOP;

    -- 3. Refresh Filters
    PERFORM refresh_cache_filters();
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
    
    -- Drop legacy inefficient indexes
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_filial;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_cidade;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_nome;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codfor;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_tipovenda;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codcli;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_ramo;

    -- Drop obsolete indexes
    DROP INDEX IF EXISTS public.idx_summary_comercial; -- Old name
    DROP INDEX IF EXISTS public.idx_summary_ano_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_nome;

    -- Recreate targeted optimized indexes (v2)
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
    
    -- Re-cluster table for physical order optimization (Manual Only)
    BEGIN
        CLUSTER public.data_summary USING idx_summary_ano_filial;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Ignore clustering errors if any
    END;

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
SET search_path = public
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
SET search_path = public
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
SET search_path = public
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

-- Drop existing overloaded functions to prevent ambiguity (PGRST203)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT oid::regprocedure AS func_signature
             FROM pg_proc
             WHERE proname IN ('get_main_dashboard_data', 'get_comparison_view_data', 'get_boxes_dashboard_data', 'get_branch_comparison_data', 'get_city_view_data')
             AND pg_function_is_visible(oid)
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.func_signature || ' CASCADE';
    END LOOP;
END $$;

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
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao, s.dtped
                FROM public.data_detailed s
                LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
                %s AND dtped >= make_date(%L, 1, 1) AND EXTRACT(YEAR FROM dtped) = %L %s
                UNION ALL
                SELECT s.vlvenda, s.totpesoliq, s.qtvenda_embalagem_master, s.produto, dp.descricao, s.dtped
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
                    SUM(totpesoliq) as peso,
                    MAX(dtped) as ultima_venda
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
                    SUM(totpesoliq) as peso,
                    MAX(dtped) as ultima_venda
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

-- H. Comparison View (Restored & Updated)
CREATE OR REPLACE FUNCTION get_comparison_view_data(
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
    -- Date Ranges
    v_ref_date date;
    v_start_target timestamp with time zone;
    v_end_target timestamp with time zone;
    v_start_quarter timestamp with time zone;
    v_end_quarter timestamp with time zone;

    -- Filter Clause
    v_where text := ' WHERE 1=1 ';
    v_where_rede text := '';

    -- Trend Vars
    v_max_sale_date date;
    v_trend_allowed boolean;
    v_trend_factor numeric := 1;
    v_month_start date;
    v_month_end date;
    v_work_days_passed int;
    v_work_days_total int;

    -- Outputs
    v_current_kpi json;
    v_history_kpi json;
    v_current_daily json;
    v_history_daily json;
    v_supervisor_data json;
    v_history_monthly json;

    -- Rede Logic Vars
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
    v_rede_condition text := '';
BEGIN
    -- Security Check
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

    SET LOCAL statement_timeout = '120s'; -- Explicitly increased for heavy agg

    -- 1. Date Logic
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        IF p_mes IS NOT NULL AND p_mes != '' THEN
            v_ref_date := make_date(p_ano::int, p_mes::int + 1, 15);
            v_end_target := (make_date(p_ano::int, p_mes::int + 1, 1) + interval '1 month' - interval '1 second');
        ELSE
            IF p_ano::int = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
                v_ref_date := CURRENT_DATE;
            ELSE
                v_ref_date := make_date(p_ano::int, 12, 31);
            END IF;
            v_end_target := (v_ref_date + interval '1 day' - interval '1 second');
        END IF;
    ELSE
        SELECT MAX(dtped) INTO v_end_target FROM public.data_detailed;
        IF v_end_target IS NULL THEN v_end_target := now(); END IF;
        v_ref_date := v_end_target::date;
    END IF;

    v_start_target := date_trunc('month', v_ref_date);
    v_end_target := (v_start_target + interval '1 month' - interval '1 second');

    v_end_quarter := v_start_target - interval '1 second';
    v_start_quarter := date_trunc('month', v_end_quarter - interval '2 months');

    -- Trend Calculation
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    v_trend_allowed := (EXTRACT(YEAR FROM v_end_target) = EXTRACT(YEAR FROM v_max_sale_date) AND EXTRACT(MONTH FROM v_end_target) = EXTRACT(MONTH FROM v_max_sale_date));

    IF v_trend_allowed THEN
        v_month_start := date_trunc('month', v_max_sale_date);
        v_month_end := (v_month_start + interval '1 month' - interval '1 day')::date;

        v_work_days_passed := public.calc_working_days(v_month_start, v_max_sale_date);
        v_work_days_total := public.calc_working_days(v_month_start, v_month_end);

        IF v_work_days_passed > 0 AND v_work_days_total > 0 THEN
            v_trend_factor := v_work_days_total::numeric / v_work_days_passed::numeric;
        END IF;
    END IF;

    -- 2. Build WHERE Clause
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where := v_where || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where := v_where || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
        v_where := v_where || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
        v_where := v_where || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;

    -- FORNECEDOR LOGIC (Modified to check joined dim_produtos for description)
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
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
                v_where := v_where || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
    END IF;

    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where := v_where || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where := v_where || format(' AND produto = ANY(%L) ', p_produto);
    END IF;

    -- REDE Logic
    IF p_rede IS NOT NULL AND array_length(p_rede, 1) > 0 THEN
       v_has_com_rede := ('C/ REDE' = ANY(p_rede));
       v_has_sem_rede := ('S/ REDE' = ANY(p_rede));
       v_specific_redes := array_remove(array_remove(p_rede, 'C/ REDE'), 'S/ REDE');

       IF array_length(v_specific_redes, 1) > 0 THEN
           v_rede_condition := format('c.ramo = ANY(%L)', v_specific_redes);
       END IF;

       IF v_has_com_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NOT NULL AND c.ramo NOT IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_has_sem_rede THEN
           IF v_rede_condition != '' THEN v_rede_condition := v_rede_condition || ' OR '; END IF;
           v_rede_condition := v_rede_condition || ' (c.ramo IS NULL OR c.ramo IN (''N/A'', ''N/D'')) ';
       END IF;

       IF v_rede_condition != '' THEN
           v_where_rede := ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Aggregation Queries

    EXECUTE format('
        WITH target_sales AS (
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_detailed s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
            UNION ALL
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_history s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
        ),
        history_sales AS (
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_detailed s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
            UNION ALL
            SELECT s.dtped, s.vlvenda, s.totpesoliq, s.codcli, s.codsupervisor, s.produto, dp.descricao, s.codfor
            FROM public.data_history s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            %s %s AND s.dtped >= %L AND s.dtped <= %L
        ),
        -- Current Aggregates
        curr_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM target_sales GROUP BY 1
        ),
        curr_prod_agg AS (
            SELECT s.codcli, s.produto, MAX(dp.mix_marca) as mix_marca, MAX(dp.mix_categoria) as mix_cat, MAX(s.codfor) as codfor, SUM(s.vlvenda) as prod_val
            FROM target_sales s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            GROUP BY 1, 2
        ),
        curr_mix_base AS (
            SELECT
                codcli,
                SUM(prod_val) as total_val,
                COUNT(CASE WHEN codfor IN (''707'', ''708'') AND prod_val >= 1 THEN 1 END) as pepsico_skus,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''CHEETOS'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''DORITOS'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''FANDANGOS'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''RUFFLES'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TORCIDA'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDYNHO'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDY'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''QUAKER'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''KEROCOCO'' THEN 1 ELSE 0 END) as has_kerococo
            FROM curr_prod_agg
            GROUP BY 1
        ),
        curr_kpi AS (
            SELECT
                SUM(ts.vlvenda) as f,
                SUM(ts.totpesoliq) as p,
                (SELECT COUNT(*) FROM curr_mix_base WHERE total_val >= 1) as c,
                COALESCE((SELECT SUM(pepsico_skus)::numeric / NULLIF(COUNT(CASE WHEN pepsico_skus > 0 THEN 1 END), 0) FROM curr_mix_base), 0) as mix_pepsico,
                COALESCE((SELECT COUNT(1) FROM curr_mix_base WHERE has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1), 0) as pos_salty,
                COALESCE((SELECT COUNT(1) FROM curr_mix_base WHERE has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1), 0) as pos_foods
            FROM target_sales ts
        ),
        curr_superv AS (
            SELECT codsupervisor as s, SUM(vlvenda) as f FROM target_sales GROUP BY 1
        ),
        -- History Aggregates
        hist_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM history_sales GROUP BY 1
        ),
        hist_prod_agg AS (
            SELECT date_trunc(''month'', dtped) as m_date, s.codcli, s.produto, MAX(dp.mix_marca) as mix_marca, MAX(dp.mix_categoria) as mix_cat, MAX(s.codfor) as codfor, SUM(s.vlvenda) as prod_val
            FROM history_sales s
            LEFT JOIN public.dim_produtos dp ON s.produto = dp.codigo
            GROUP BY 1, 2, 3
        ),
        hist_monthly_mix AS (
            SELECT
                m_date,
                codcli,
                SUM(prod_val) as total_val,
                COUNT(CASE WHEN codfor IN (''707'', ''708'') AND prod_val >= 1 THEN 1 END) as pepsico_skus,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''CHEETOS'' THEN 1 ELSE 0 END) as has_cheetos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''DORITOS'' THEN 1 ELSE 0 END) as has_doritos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''FANDANGOS'' THEN 1 ELSE 0 END) as has_fandangos,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''RUFFLES'' THEN 1 ELSE 0 END) as has_ruffles,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TORCIDA'' THEN 1 ELSE 0 END) as has_torcida,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDYNHO'' THEN 1 ELSE 0 END) as has_toddynho,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''TODDY'' THEN 1 ELSE 0 END) as has_toddy,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''QUAKER'' THEN 1 ELSE 0 END) as has_quaker,
                MAX(CASE WHEN prod_val >= 1 AND mix_marca = ''KEROCOCO'' THEN 1 ELSE 0 END) as has_kerococo
            FROM hist_prod_agg
            GROUP BY 1, 2
        ),
        hist_monthly_sums AS (
            SELECT
                m_date,
                SUM(total_val) as monthly_f,
                COUNT(CASE WHEN total_val >= 1 THEN 1 END) as monthly_active_clients,
                COALESCE(SUM(pepsico_skus)::numeric / NULLIF(COUNT(CASE WHEN pepsico_skus > 0 THEN 1 END), 0), 0) as monthly_mix_pepsico,
                COUNT(CASE WHEN has_cheetos=1 AND has_doritos=1 AND has_fandangos=1 AND has_ruffles=1 AND has_torcida=1 THEN 1 END) as monthly_pos_salty,
                COUNT(CASE WHEN has_toddynho=1 AND has_toddy=1 AND has_quaker=1 AND has_kerococo=1 THEN 1 END) as monthly_pos_foods
            FROM hist_monthly_mix
            GROUP BY 1
        ),
        hist_kpi AS (
            SELECT
                SUM(ts.vlvenda) as f,
                SUM(ts.totpesoliq) as p,
                COALESCE((SELECT SUM(monthly_active_clients) FROM hist_monthly_sums), 0) as c,
                COALESCE((SELECT SUM(monthly_mix_pepsico) FROM hist_monthly_sums), 0) as sum_mix_pepsico,
                COALESCE((SELECT SUM(monthly_pos_salty) FROM hist_monthly_sums), 0) as sum_pos_salty,
                COALESCE((SELECT SUM(monthly_pos_foods) FROM hist_monthly_sums), 0) as sum_pos_foods
            FROM history_sales ts
        ),
        hist_superv AS (
            SELECT codsupervisor as s, SUM(vlvenda) as f FROM history_sales GROUP BY 1
        ),
        hist_monthly AS (
             SELECT to_char(m_date, ''YYYY-MM'') as m, monthly_f as f, monthly_active_clients as c
             FROM hist_monthly_sums
        )
        SELECT
            COALESCE((SELECT json_agg(row_to_json(curr_daily.*)) FROM curr_daily), ''[]''),
            COALESCE((SELECT row_to_json(curr_kpi.*) FROM curr_kpi), ''{}''),
            COALESCE((SELECT json_agg(row_to_json(hist_daily.*)) FROM hist_daily), ''[]''),
            COALESCE((SELECT row_to_json(hist_kpi.*) FROM hist_kpi), ''{}''),
            COALESCE((SELECT json_agg(json_build_object(
                ''name'', COALESCE(ds.nome, ''Outros''),
                ''current'', COALESCE(cs.f, 0),
                ''history'', COALESCE(hs.f, 0)
            ))
            FROM (SELECT DISTINCT s FROM curr_superv UNION SELECT DISTINCT s FROM hist_superv) all_s
            LEFT JOIN curr_superv cs ON all_s.s = cs.s
            LEFT JOIN hist_superv hs ON all_s.s = hs.s
            LEFT JOIN public.dim_supervisores ds ON all_s.s = ds.codigo
            ), ''[]''),
            COALESCE((SELECT json_agg(row_to_json(hist_monthly.*)) FROM hist_monthly), ''[]'')
    ',
    v_where, v_where_rede, v_start_target, v_end_target,
    v_where, v_where_rede, v_start_target, v_end_target,
    v_where, v_where_rede, v_start_quarter, v_end_quarter,
    v_where, v_where_rede, v_start_quarter, v_end_quarter
    ) INTO v_current_daily, v_current_kpi, v_history_daily, v_history_kpi, v_supervisor_data, v_history_monthly;

    RETURN json_build_object(
        'current_daily', v_current_daily,
        'current_kpi', v_current_kpi,
        'history_daily', v_history_daily,
        'history_kpi', v_history_kpi,
        'supervisor_data', v_supervisor_data,
        'history_monthly', v_history_monthly,
        'trend_info', json_build_object('allowed', v_trend_allowed, 'factor', v_trend_factor),
        'debug_range', json_build_object('start', v_start_target, 'end', v_end_target, 'h_start', v_start_quarter, 'h_end', v_end_quarter)
    );
END;
$$;
