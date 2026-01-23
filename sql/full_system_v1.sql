
-- ==============================================================================
-- UNIFIED DATABASE SETUP & OPTIMIZED SYSTEM SCRIPT
-- Contains: Tables, Dynamic SQL, Partial Indexes, Summary Logic, RLS, Trends, Caching
-- Consolidates all previous SQL files into one master schema.
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
  codusur text,
  codsupervisor text,
  produto text,
  descricao text,
  codfor text,
  observacaofor text,
  codcli text,
  cliente_nome text,
  cidade text,
  bairro text,
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
  descricao text,
  codfor text,
  observacaofor text,
  codcli text,
  cliente_nome text,
  cidade text,
  bairro text,
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
    pre_mix_count int DEFAULT 0,
    pre_positivacao_val int DEFAULT 0, -- 1 se positivou, 0 se não
    ramo text, -- ADDED: Rede Filter
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

-- Summary Table Targeted Indexes (For Dynamic SQL)
-- V2 Optimized Indexes (Year + Dimension) - Removing Month from prefix
CREATE INDEX IF NOT EXISTS idx_summary_composite_main ON public.data_summary (ano, mes, filial, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_comercial ON public.data_summary (superv, nome, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_ano_superv ON public.data_summary (ano, superv);
CREATE INDEX IF NOT EXISTS idx_summary_ano_nome ON public.data_summary (ano, nome); -- Vendedor
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

-- Refresh Filters Cache Function
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
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
            WHEN t.codfor = '1119' THEN '1119_OUTROS'
            ELSE t.codfor 
        END as codfor,
        CASE 
            WHEN t.codfor = '707' THEN 'EXTRUSADOS'
            WHEN t.codfor = '708' THEN 'Ñ EXTRUSADOS'
            WHEN t.codfor = '752' THEN 'TORCIDA'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%TODDYNHO%' THEN 'TODDYNHO'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%TODDY %' THEN 'TODDY'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%QUAKER%' THEN 'QUAKER'
            WHEN t.codfor = '1119' AND t.descricao ILIKE '%KEROCOCO%' THEN 'KEROCOCO'
            WHEN t.codfor = '1119' THEN 'FOODS (Outros)'
            ELSE df.nome 
        END as fornecedor, 
        t.tipovenda, 
        t.yr, 
        t.mth,
        c.ramo as rede
    FROM (
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli, descricao,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, codsupervisor, codusur as codvendedor, codfor, tipovenda, codcli, descricao,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth 
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente
    LEFT JOIN public.dim_supervisores ds ON t.codsupervisor = ds.codigo
    LEFT JOIN public.dim_vendedores dv ON t.codvendedor = dv.codigo
    LEFT JOIN public.dim_fornecedores df ON t.codfor = df.codigo;
END;
$$;

-- Refresh Summary Cache Function (Optimized with Mix Products Array)
CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;
    
    -- Inserção OTIMIZADA: Já calcula se houve positivação e contagem de mix
    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, 
        vlvenda, peso, bonificacao, devolucao, 
        pre_mix_count, pre_positivacao_val,
        ramo
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, descricao 
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto, descricao 
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
            ds.nome as superv, 
            COALESCE(dv.nome, c.nomecliente) as nome, 
            CASE 
                WHEN s.codfor = '1119' AND s.descricao ILIKE '%TODDYNHO%' THEN '1119_TODDYNHO'
                WHEN s.codfor = '1119' AND s.descricao ILIKE '%TODDY %' THEN '1119_TODDY'
                WHEN s.codfor = '1119' AND s.descricao ILIKE '%QUAKER%' THEN '1119_QUAKER'
                WHEN s.codfor = '1119' AND s.descricao ILIKE '%KEROCOCO%' THEN '1119_KEROCOCO'
                WHEN s.codfor = '1119' THEN '1119_OUTROS'
                ELSE s.codfor 
            END as codfor, 
            s.tipovenda, 
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto,
            c.ramo
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_supervisores ds ON s.codsupervisor = ds.codigo
        LEFT JOIN public.dim_vendedores dv ON s.codusur = dv.codigo
    ),
    product_agg AS (
        SELECT 
            ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli, ramo, produto,
            SUM(vlvenda) as prod_val,
            SUM(totpesoliq) as prod_peso,
            SUM(vlbonific) as prod_bonific,
            SUM(COALESCE(vldevolucao, 0)) as prod_devol
        FROM augmented_data
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
    ),
    client_agg AS (
        SELECT 
            pa.ano, pa.mes, pa.filial, pa.cidade, pa.superv, pa.nome, pa.codfor, pa.tipovenda, pa.codcli, pa.ramo,
            SUM(pa.prod_val) as total_val,
            SUM(pa.prod_peso) as total_peso,
            SUM(pa.prod_bonific) as total_bonific,
            SUM(pa.prod_devol) as total_devol,
            -- Cálculo de Mix Direto na Agregação (Substitui JSONB)
            COUNT(CASE WHEN pa.prod_val >= 1 THEN 1 END) as mix_calc
        FROM product_agg pa
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    )
    SELECT 
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        total_val, total_peso, total_bonific, total_devol,
        mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc,
        ramo
    FROM client_agg;
    
    -- CLUSTER removed to prevent timeouts during auto-refresh. Moved to optimize_database().
    -- CLUSTER public.data_summary USING idx_summary_ano_filial;
    ANALYZE public.data_summary;
END;
$$;

-- Refresh Cache & Summary Function (Legacy Wrapper)
CREATE OR REPLACE FUNCTION refresh_dashboard_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    
    -- Drop legacy inefficient indexes
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_filial;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_cidade;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_nome;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codfor;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_tipovenda;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codcli;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_ramo;

    -- Recreate targeted optimized indexes (v2)
    CREATE INDEX IF NOT EXISTS idx_summary_composite_main ON public.data_summary (ano, mes, filial, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_comercial ON public.data_summary (superv, nome, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_superv ON public.data_summary (ano, superv);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_nome ON public.data_summary (ano, nome);
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

    -- Configurações de Memória para esta Query Específica
    SET LOCAL work_mem = '64MB'; -- Aumenta memória para ordenação
    SET LOCAL statement_timeout = '60s'; -- Aumentado para 60s para suportar volumes maiores

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
    -- IMPORTANT: tipovenda filter REMOVED from base WHERE to handle conditional aggregation logic
    -- IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
    --    v_where_base := v_where_base || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    -- END IF;
    
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

    -- MIX Constraint Logic (Default to 707/708 if no provider filter, else use all filtered)
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

    -- FILIAL LOGIC FOR KPI (Clients Base)
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

    -- 4. Execute Main Aggregation Query (VERSÃO OTIMIZADA)
    -- Removemos todas as subqueries complexas (mix_raw_data, monthly_mix_stats, etc)
    v_sql := '
    WITH filtered_summary AS (
        SELECT ano, mes, vlvenda, peso, bonificacao, devolucao, pre_positivacao_val, pre_mix_count, codcli, tipovenda, codfor
        FROM public.data_summary
        ' || v_where_base || '
    ),
    -- CORREÇÃO: Agregação por Cliente para Positivação (Net Sales >= 1 ou Bonificação > 0)
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
            -- Agregação simples e direta

            -- Faturamento: Se filtro existe, respeita. Se não, padrão 1 e 9.
            SUM(CASE 
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.vlvenda ELSE 0 END
                WHEN fs.tipovenda IN (''1'', ''9'') THEN fs.vlvenda
                ELSE 0 
            END) as faturamento,

            -- Venda Base (Total Vendido Normal - Ignora filtro de Tipo Venda para denominador de KPI)
            SUM(CASE
                WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.vlvenda
                ELSE 0
            END) as total_sold_base,

            -- Peso:
            SUM(CASE
                -- Caso A: Filtro SOMENTE tipos de bonificação (5 ou 11)
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 <@ ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) THEN fs.peso ELSE 0 END

                -- Caso B: Filtro Padrão (Sem filtro, ou filtro inclui vendas normais)
                -- Exclui tipos 5 e 11
                ELSE
                    CASE
                        -- Se filtro existe (ex: Venda Normal), aplica filtro E exclui bonus
                        WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                             CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso ELSE 0 END

                        -- Se não tem filtro: Soma tudo MENOS bonus 5 e 11
                        WHEN fs.tipovenda NOT IN (''5'', ''11'') THEN fs.peso
                        ELSE 0
                    END
            END) as peso,

            -- Bonificação:
            SUM(CASE
                -- Caso A: Filtro contém ALGUM tipo de bonificação (5 ou 11) -> Respeita filtro
                -- (Altera lógica de subset <@ para overlap && para permitir mixes como [1, 11])
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0 AND $1 && ARRAY[''5'',''11'']) THEN
                     CASE WHEN fs.tipovenda = ANY($1) AND fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END

                -- Caso B: Filtro não contém nenhum tipo de bonificação -> Mostra TODOS os bonus (5 e 11)
                ELSE
                     CASE WHEN fs.tipovenda IN (''5'', ''11'') THEN fs.bonificacao ELSE 0 END
            END) as bonificacao,

            -- Devolução: Segue lógica padrão de filtro
            SUM(CASE
                WHEN ($1 IS NOT NULL AND COALESCE(array_length($1, 1), 0) > 0) THEN
                    CASE WHEN fs.tipovenda = ANY($1) THEN fs.devolucao ELSE 0 END
                ELSE fs.devolucao
            END) as devolucao,

            -- Positivação Corrigida (Join com pré-cálculo por cliente)
            COALESCE(mc.active_count, 0) as positivacao_count,

            -- Mix pré-calculado (Respeitando regra de Venda/Venda Futura se filtro não for especificado)
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
            -- Filtro Tipos de Venda para KPI Active Count (apenas Venda Normal ou Filtro Selecionado)
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
        -- Gerar JSON diretamente
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

-- Get Dashboard Filters (Split Queries for Speed)
-- NOTE: We explicitly drop potential overlapping signatures before re-creating the definitive one.
DROP FUNCTION IF EXISTS public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[], text[]);
DROP FUNCTION IF EXISTS public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text, text[]);
DROP FUNCTION IF EXISTS public.get_dashboard_filters(text[], text[], text[], text[], text[], text, text);

CREATE OR REPLACE FUNCTION get_dashboard_filters(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_supervisors text[];
    v_vendedores text[];
    v_fornecedores json;
    v_cidades text[];
    v_filiais text[];
    v_anos int[];
    v_tipos_venda text[];
    v_redes text[];
    v_produtos json; -- NEW
    v_filter_year int;
    v_filter_month int;
BEGIN
    IF NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso negado'; END IF;

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
    SELECT json_agg(json_build_object('cod', codfor, 'name', fornecedor) ORDER BY 
        CASE 
            WHEN codfor = '707' THEN 1 
            WHEN codfor = '708' THEN 2 
            WHEN codfor = '752' THEN 3 
            WHEN codfor = '1119_TODDYNHO' THEN 4
            WHEN codfor = '1119_TODDY' THEN 5
            WHEN codfor = '1119_QUAKER' THEN 6
            WHEN codfor = '1119_KEROCOCO' THEN 7
            WHEN codfor = '1119_OUTROS' THEN 8
            ELSE 99 
        END, fornecedor
    ) INTO v_fornecedores
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

    -- 7. Redes
    SELECT ARRAY(SELECT DISTINCT rede FROM public.cache_filters WHERE
        (v_filter_year IS NULL OR ano = v_filter_year)
        AND (p_filial IS NULL OR array_length(p_filial, 1) IS NULL OR filial = ANY(p_filial))
        AND (p_cidade IS NULL OR array_length(p_cidade, 1) IS NULL OR cidade = ANY(p_cidade))
        AND (p_supervisor IS NULL OR array_length(p_supervisor, 1) IS NULL OR superv = ANY(p_supervisor))
        AND (p_vendedor IS NULL OR array_length(p_vendedor, 1) IS NULL OR nome = ANY(p_vendedor))
        AND (p_fornecedor IS NULL OR array_length(p_fornecedor, 1) IS NULL OR codfor = ANY(p_fornecedor))
        AND (p_tipovenda IS NULL OR array_length(p_tipovenda, 1) IS NULL OR tipovenda = ANY(p_tipovenda))
        AND (v_filter_month IS NULL OR mes = v_filter_month)
        AND rede IS NOT NULL AND rede != '' AND rede != 'null' AND rede != 'N/A' AND rede != 'N/D'
        ORDER BY rede
    ) INTO v_redes;

    -- 8. Anos
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

    -- 9. Produtos (Filtered by Fornecedor AND Sales Existence)
    SELECT json_agg(json_build_object('cod', codigo, 'name', descricao || ' (' || codigo || ')') ORDER BY descricao)
    INTO v_produtos
    FROM public.dim_produtos
    WHERE (
        CASE
            WHEN p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
               (
                 -- 1. Standard match for non-1119 codes
                 (codfor != '1119' AND codfor = ANY(p_fornecedor))
                 OR
                 -- 2. 1119 match logic (Check description for specific subtypes)
                 (codfor = '1119' AND (
                     ('1119_KEROCOCO' = ANY(p_fornecedor) AND descricao ILIKE '%KEROCOCO%') OR
                     ('1119_QUAKER'   = ANY(p_fornecedor) AND descricao ILIKE '%QUAKER%') OR
                     ('1119_TODDYNHO' = ANY(p_fornecedor) AND descricao ILIKE '%TODDYNHO%') OR
                     ('1119_TODDY'    = ANY(p_fornecedor) AND descricao ILIKE '%TODDY %') OR
                     ('1119_OUTROS'   = ANY(p_fornecedor) AND descricao NOT ILIKE '%KEROCOCO%' AND descricao NOT ILIKE '%QUAKER%' AND descricao NOT ILIKE '%TODDYNHO%' AND descricao NOT ILIKE '%TODDY %')
                 ))
               )
            ELSE 1=1
        END
    )
    -- Filter to only include products that have sales
    AND (
        EXISTS (SELECT 1 FROM public.data_detailed d WHERE d.produto = public.dim_produtos.codigo)
        OR
        EXISTS (SELECT 1 FROM public.data_history h WHERE h.produto = public.dim_produtos.codigo)
    );

    RETURN json_build_object(
        'supervisors', COALESCE(v_supervisors, '{}'), 
        'vendedores', COALESCE(v_vendedores, '{}'), 
        'fornecedores', COALESCE(v_fornecedores, '[]'::json), 
        'cidades', COALESCE(v_cidades, '{}'), 
        'filiais', COALESCE(v_filiais, '{}'), 
        'redes', COALESCE(v_redes, '{}'),
        'anos', COALESCE(v_anos, '{}'), 
        'tipos_venda', COALESCE(v_tipos_venda, '{}'),
        'produtos', COALESCE(v_produtos, '[]'::json)
    );
END;
$$;

-- Function: Get City View (Paginated for both Active and Inactive, No RCA2)
-- Re-defining with correct Dynamic SQL logic matching fast_response_rpc.sql to ensure complete_system.sql is valid.
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
    SET LOCAL statement_timeout = '120s'; -- Timeout increased for large datasets

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
           -- Apply to summary
           v_where := v_where || ' AND (' || v_rede_condition || ') ';
           -- Apply to clients
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
        json_build_object(
            ''cols'', json_build_array(''Código'', ''fantasia'', ''razaoSocial'', ''cidade'', ''bairro'', ''ultimaCompra'', ''rca1''),
            ''rows'', COALESCE(json_agg(json_build_array(pi.codigo_cliente, pi.fantasia, pi.razaosocial, pi.cidade, pi.bairro, pi.ultimacompra, pi.rca1) ORDER BY pi.ultimacompra DESC NULLS LAST), ''[]''::json)
        )
    FROM paginated_inactive pi;
    ';

    EXECUTE v_sql INTO v_total_inactive_count, v_inactive_clients USING p_inactive_limit, p_inactive_page;

    RETURN json_build_object(
        'active_clients', v_active_clients, -- Already in cols/rows object format from subquery
        'total_active_count', COALESCE(v_total_active_count, 0),
        'inactive_clients', v_inactive_clients,
        'total_inactive_count', COALESCE(v_total_inactive_count, 0)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. NEW RPC: GET BRANCH COMPARISON (Aggregated)
-- ------------------------------------------------------------------------------
-- 2. Create get_boxes_dashboard_data
-- Update get_boxes_dashboard_data to return Chart (Full Year), KPI Current, KPI Previous (Same Period), and KPI Tri Avg (Prior Quarter)

CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null
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
    
    v_where_common text := ' WHERE 1=1 ';
    
    -- Outputs
    v_chart_data json;
    v_kpis_current json;
    v_kpis_previous json;
    v_kpis_tri_avg json;
    v_products_table json;

    -- Helpers
    v_rede_condition text := '';
    v_has_com_rede boolean;
    v_has_sem_rede boolean;
    v_specific_redes text[];
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

    -- Determine Reference Date for Tri Logic
    IF p_mes IS NOT NULL AND p_mes != '' AND p_mes != 'todos' THEN
        v_target_month := p_mes::int + 1;
        -- Target is 1st of selected month. Tri is previous 3 months.
        v_ref_date := make_date(v_current_year, v_target_month, 1);
    ELSE
        -- No month selected.
        IF v_current_year < EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
            -- Past year -> Dec is reference (so Tri is Sep/Oct/Nov?)
            -- User: "média do trimestre anterior ao mês mais recente"
            -- If year is full, most recent is Dec. Tri anterior to Dec is Sep/Oct/Nov.
            -- v_ref_date = 1st Dec.
            v_ref_date := make_date(v_current_year, 12, 1);
        ELSE
             -- Current Year -> Current Month.
             v_ref_date := date_trunc('month', CURRENT_DATE)::date;
        END IF;
    END IF;

    -- Tri Calculation: 3 months before v_ref_date.
    -- e.g. Ref = May 1st. Tri = Feb 1st to Apr 30th.
    v_tri_end := (v_ref_date - interval '1 day')::date;
    v_tri_start := (v_ref_date - interval '3 months')::date;


    -- 2. Build COMMON WHERE (Exclude Time filters)
    -- Applied to data_detailed/history directly
    
    IF p_filial IS NOT NULL AND array_length(p_filial, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND filial = ANY(%L) ', p_filial);
    END IF;
    IF p_cidade IS NOT NULL AND array_length(p_cidade, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND cidade = ANY(%L) ', p_cidade);
    END IF;
    IF p_supervisor IS NOT NULL AND array_length(p_supervisor, 1) > 0 THEN
         -- Optimization: Join is better but for dynamic string building:
         v_where_common := v_where_common || format(' AND codsupervisor IN (SELECT codigo FROM dim_supervisores WHERE nome = ANY(%L)) ', p_supervisor);
    END IF;
    IF p_vendedor IS NOT NULL AND array_length(p_vendedor, 1) > 0 THEN
         v_where_common := v_where_common || format(' AND codusur IN (SELECT codigo FROM dim_vendedores WHERE nome = ANY(%L)) ', p_vendedor);
    END IF;
    IF p_tipovenda IS NOT NULL AND array_length(p_tipovenda, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND tipovenda = ANY(%L) ', p_tipovenda);
    END IF;
    IF p_produto IS NOT NULL AND array_length(p_produto, 1) > 0 THEN
        v_where_common := v_where_common || format(' AND produto = ANY(%L) ', p_produto);
    END IF;
    
    -- Fornecedor Logic
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao NOT ILIKE ''%TODDYNHO%'' AND descricao NOT ILIKE ''%TODDY %'' AND descricao NOT ILIKE ''%QUAKER%'' AND descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;
            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('codfor = ANY(%L)', v_simple_codes));
            END IF;
            IF array_length(v_conditions, 1) > 0 THEN
                v_where_common := v_where_common || ' AND (' || array_to_string(v_conditions, ' OR ') || ') ';
            END IF;
        END;
    END IF;

    -- REDE Logic (Exists check on Clients)
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
           v_where_common := v_where_common || ' AND EXISTS (SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente = s.codcli AND (' || v_rede_condition || ')) ';
       END IF;
    END IF;

    -- 3. Execute Queries

    EXECUTE format('
        WITH base_data AS (
            SELECT dtped, vlvenda, totpesoliq, qtvenda_embalagem_master, produto, descricao, filial
            FROM public.data_detailed s
            %s
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, qtvenda_embalagem_master, produto, descricao, filial
            FROM public.data_history s
            %s
        ),
        -- Chart Data (Current vs Previous Year, Full 12 Months)
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
        -- KPI Current (Selected Year + Optional Month)
        kpi_curr AS (
            SELECT 
                SUM(vlvenda) as fat,
                SUM(totpesoliq) as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter
        ),
        -- KPI Previous (Previous Year + Optional Month)
        kpi_prev AS (
            SELECT 
                SUM(vlvenda) as fat,
                SUM(totpesoliq) as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter (Same month index)
        ),
        -- KPI Tri Avg (Specific Date Range)
        kpi_tri AS (
            SELECT 
                SUM(vlvenda) / 3 as fat,
                SUM(totpesoliq) / 3 as peso,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) / 3 as caixas
            FROM base_data
            WHERE dtped >= %L AND dtped <= %L
        ),
        -- Products Table (Selected Year + Optional Month)
        prod_agg AS (
            SELECT
                produto,
                MAX(descricao) as descricao,
                SUM(COALESCE(qtvenda_embalagem_master, 0)) as caixas,
                SUM(vlvenda) as faturamento,
                SUM(totpesoliq) as peso
            FROM base_data
            WHERE EXTRACT(YEAR FROM dtped) = %L
            %s -- Optional Month Filter
            GROUP BY 1
            ORDER BY caixas DESC
            LIMIT 50
        )
        SELECT 
            (SELECT json_agg(json_build_object(
                ''month_index'', m_idx, 
                ''year'', yr, 
                ''faturamento'', fat, 
                ''peso'', peso, 
                ''caixas'', caixas
             )) FROM chart_agg),
             
            (SELECT row_to_json(c) FROM kpi_curr c),
            (SELECT row_to_json(p) FROM kpi_prev p),
            (SELECT row_to_json(t) FROM kpi_tri t),
            (SELECT json_agg(pa) FROM prod_agg pa)
    ', 
    v_where_common, v_where_common, -- CTE
    v_current_year, v_previous_year, -- Chart
    v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- KPI Curr
    v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- KPI Prev
    v_tri_start, v_tri_end, -- KPI Tri
    v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END -- Prod Table
    )
    INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    -- Transform Chart Data into friendly structure (group by month)
    -- Or let JS do it. JS expects array of months.
    -- Let's stick to raw rows and map in JS, or format nicely here.
    -- Better format here: Array of 12 items, each with current and previous.
    
    RETURN json_build_object(
        'chart_data', COALESCE(v_chart_data, '[]'::json),
        'kpi_current', COALESCE(v_kpis_current, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_previous', COALESCE(v_kpis_previous, '{"fat":0,"peso":0,"caixas":0}'::json),
        'kpi_tri_avg', COALESCE(v_kpis_tri_avg, '{"fat":0,"peso":0,"caixas":0}'::json),
        'products_table', COALESCE(v_products_table, '[]'::json),
        'debug_tri', json_build_object('start', v_tri_start, 'end', v_tri_end)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. NEW RPC: GET BRANCH COMPARISON (Aggregated)
-- ------------------------------------------------------------------------------
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




-- RPC for Comparison View (Optimized for Performance & Completeness)
CREATE OR REPLACE FUNCTION get_comparison_view_data(
    p_filial text[] default null,
    p_cidade text[] default null,
    p_supervisor text[] default null,
    p_vendedor text[] default null,
    p_fornecedor text[] default null,
    p_ano text default null,
    p_mes text default null,
    p_tipovenda text[] default null,
    p_rede text[] default null
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
    
    -- 1. Date Logic (Mirrors JS fetchComparisonData)
    IF p_ano IS NOT NULL AND p_ano != 'todos' AND p_ano != '' THEN
        IF p_mes IS NOT NULL AND p_mes != '' THEN
            -- Year + Month Selected
            v_ref_date := make_date(p_ano::int, p_mes::int + 1, 15); -- Mid-month
            v_end_target := (make_date(p_ano::int, p_mes::int + 1, 1) + interval '1 month' - interval '1 second');
        ELSE
            -- Year Selected, No Month -> Use Dec 31 of that year OR Current Date if Current Year
            IF p_ano::int = EXTRACT(YEAR FROM CURRENT_DATE)::int THEN
                v_ref_date := CURRENT_DATE;
            ELSE
                v_ref_date := make_date(p_ano::int, 12, 31);
            END IF;
            v_end_target := (v_ref_date + interval '1 day' - interval '1 second'); -- End of ref day approx
        END IF;
    ELSE
        -- No Year -> Default to Last Sales Date or Now (We use Now/Max DB Date)
        SELECT MAX(dtped) INTO v_end_target FROM public.data_detailed;
        IF v_end_target IS NULL THEN v_end_target := now(); END IF;
        v_ref_date := v_end_target::date;
    END IF;

    -- Calculate Start/End
    v_start_target := date_trunc('month', v_ref_date);
    v_end_target := (v_start_target + interval '1 month' - interval '1 second');
    
    -- Comparison Quarter (Previous 3 Months)
    v_end_quarter := v_start_target - interval '1 second';
    v_start_quarter := date_trunc('month', v_end_quarter - interval '2 months');

    -- Trend Calculation
    SELECT MAX(dtped)::date INTO v_max_sale_date FROM public.data_detailed;
    IF v_max_sale_date IS NULL THEN v_max_sale_date := CURRENT_DATE; END IF;

    -- Trend Allowed logic (Simplified: Target Year/Month must match Max Sale Date Year/Month)
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
    
    -- FORNECEDOR LOGIC (DYNAMIC OR/AND)
    IF p_fornecedor IS NOT NULL AND array_length(p_fornecedor, 1) > 0 THEN
        DECLARE
            v_code text;
            v_conditions text[] := '{}';
            v_simple_codes text[] := '{}';
        BEGIN
            FOREACH v_code IN ARRAY p_fornecedor LOOP
                IF v_code = '1119_TODDYNHO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDYNHO%'')');
                ELSIF v_code = '1119_TODDY' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%TODDY %'')');
                ELSIF v_code = '1119_QUAKER' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%QUAKER%'')');
                ELSIF v_code = '1119_KEROCOCO' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao ILIKE ''%KEROCOCO%'')');
                ELSIF v_code = '1119_OUTROS' THEN
                    v_conditions := array_append(v_conditions, '(codfor = ''1119'' AND descricao NOT ILIKE ''%TODDYNHO%'' AND descricao NOT ILIKE ''%TODDY %'' AND descricao NOT ILIKE ''%QUAKER%'' AND descricao NOT ILIKE ''%KEROCOCO%'')');
                ELSE
                    v_simple_codes := array_append(v_simple_codes, v_code);
                END IF;
            END LOOP;

            IF array_length(v_simple_codes, 1) > 0 THEN
                v_conditions := array_append(v_conditions, format('codfor = ANY(%L)', v_simple_codes));
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

    -- REDE Logic (Requires Join with Clients or Ramo check if denormalized)
    -- data_detailed/history do NOT have 'ramo'. We must join data_clients.
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

    -- 3. Aggregation Queries (Optimized with CTEs & Auto-Mix)
    
    EXECUTE format('
        WITH target_sales AS (
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_detailed s %s %s AND dtped >= %L AND dtped <= %L
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_history s %s %s AND dtped >= %L AND dtped <= %L
        ),
        history_sales AS (
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_detailed s %s %s AND dtped >= %L AND dtped <= %L
            UNION ALL
            SELECT dtped, vlvenda, totpesoliq, codcli, codsupervisor, produto, descricao, codfor
            FROM public.data_history s %s %s AND dtped >= %L AND dtped <= %L
        ),
        -- Current Aggregates
        curr_daily AS (
            SELECT dtped::date as d, SUM(vlvenda) as f, SUM(totpesoliq) as p
            FROM target_sales GROUP BY 1
        ),
        -- Current Aggregates for Product Mix (Joined with Dimensions)
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
        -- History Aggregates for Product Mix (Joined with Dimensions)
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


-- ==============================================================================
-- 5. INITIALIZATION (Populate City Mapping & Dimensions + Refresh)
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

-- Populate Dimensions from Existing Data (Migration)
-- Supervisors
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'superv') THEN
        EXECUTE 'INSERT INTO public.dim_supervisores (codigo, nome)
                 SELECT codsupervisor, MAX(superv)
                 FROM public.data_history
                 WHERE codsupervisor IS NOT NULL AND codsupervisor != '''' AND superv IS NOT NULL
                 GROUP BY codsupervisor
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'superv') THEN
        EXECUTE 'INSERT INTO public.dim_supervisores (codigo, nome)
                 SELECT codsupervisor, MAX(superv)
                 FROM public.data_detailed
                 WHERE codsupervisor IS NOT NULL AND codsupervisor != '''' AND superv IS NOT NULL
                 GROUP BY codsupervisor
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
END $$;

-- Vendors
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'nome') THEN
        EXECUTE 'INSERT INTO public.dim_vendedores (codigo, nome)
                 SELECT codusur, MAX(nome)
                 FROM public.data_history
                 WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
                 GROUP BY codusur
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'nome') THEN
        EXECUTE 'INSERT INTO public.dim_vendedores (codigo, nome)
                 SELECT codusur, MAX(nome)
                 FROM public.data_detailed
                 WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
                 GROUP BY codusur
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
END $$;

-- Suppliers
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'fornecedor') THEN
        EXECUTE 'INSERT INTO public.dim_fornecedores (codigo, nome)
                 SELECT codfor, MAX(fornecedor)
                 FROM public.data_history
                 WHERE codfor IS NOT NULL AND codfor != '''' AND fornecedor IS NOT NULL
                 GROUP BY codfor
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'fornecedor') THEN
        EXECUTE 'INSERT INTO public.dim_fornecedores (codigo, nome)
                 SELECT codfor, MAX(fornecedor)
                 FROM public.data_detailed
                 WHERE codfor IS NOT NULL AND codfor != '''' AND fornecedor IS NOT NULL
                 GROUP BY codfor
                 ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome';
    END IF;
END $$;

-- Fix Americanas Supervisor Mapping
-- Ensure code 8 is BALCAO and SV_AMERICANAS is SV AMERICANAS
INSERT INTO public.dim_supervisores (codigo, nome) VALUES ('8', 'BALCAO')
ON CONFLICT (codigo) DO UPDATE SET nome = 'BALCAO';

INSERT INTO public.dim_supervisores (codigo, nome) VALUES ('SV_AMERICANAS', 'SV AMERICANAS')
ON CONFLICT (codigo) DO UPDATE SET nome = 'SV AMERICANAS';

-- Cleanup dim_produtos logic (Ensure only specific suppliers are kept)
-- Run in DO block to execute as a statement
DO $$
BEGIN
    DELETE FROM public.dim_produtos
    WHERE codfor NOT IN ('707', '708', '752', '1119');
END $$;

-- SELECT refresh_dashboard_cache(); -- Disabled auto-run to prevent immediate locking

-- GRANTs for client-side execution (Split logic)
GRANT EXECUTE ON FUNCTION public.refresh_cache_filters() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_cache_summary() TO authenticated;

-- Migration: Add qtvenda_embalagem_master to data tables if missing
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'qtvenda_embalagem_master') THEN
        ALTER TABLE public.data_detailed ADD COLUMN qtvenda_embalagem_master numeric;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'qtvenda_embalagem_master') THEN
        ALTER TABLE public.data_history ADD COLUMN qtvenda_embalagem_master numeric;
    END IF;
END $$;
