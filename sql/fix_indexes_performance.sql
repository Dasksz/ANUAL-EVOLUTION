-- ==============================================================================
-- DASHBOARD PERFORMANCE FIX: INDEX OPTIMIZATION
-- ==============================================================================

-- 1. Drop Inefficient Indexes (Prefix contains 'mes', but query uses 'ano' + dimension)
DROP INDEX IF EXISTS public.idx_summary_ano_mes_filial;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_cidade;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_superv;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_nome;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_codfor;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_tipovenda;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_codcli;
DROP INDEX IF EXISTS public.idx_summary_ano_mes_ramo;

-- 2. Create Optimized Indexes (Year + Dimension)
-- 'mes' is deliberately excluded from the prefix to allow Range Scans on Year + Index Scan on Dimension
-- 'mes' is included as a suffix or included column for index-only scans if possible, but B-Tree is enough.
CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
CREATE INDEX IF NOT EXISTS idx_summary_ano_superv ON public.data_summary (ano, superv);
CREATE INDEX IF NOT EXISTS idx_summary_ano_nome ON public.data_summary (ano, nome); -- Vendedor
CREATE INDEX IF NOT EXISTS idx_summary_ano_codfor ON public.data_summary (ano, codfor);
CREATE INDEX IF NOT EXISTS idx_summary_ano_tipovenda ON public.data_summary (ano, tipovenda);
CREATE INDEX IF NOT EXISTS idx_summary_ano_codcli ON public.data_summary (ano, codcli);
CREATE INDEX IF NOT EXISTS idx_summary_ano_ramo ON public.data_summary (ano, ramo);

-- 3. Optimize Clients Table (for KPI Counts)
CREATE INDEX IF NOT EXISTS idx_clients_bloqueio_cidade ON public.data_clients (bloqueio, cidade);
CREATE INDEX IF NOT EXISTS idx_clients_ramo ON public.data_clients (ramo); -- Used for Rede Filters

-- 4. Update 'optimize_database' RPC to enforce these new indexes in future
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

    -- Drop legacy inefficient indexes
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_filial;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_cidade;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_superv;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_nome;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codfor;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_tipovenda;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_codcli;
    DROP INDEX IF EXISTS public.idx_summary_ano_mes_ramo;
    
    -- Drop potentially heavy unused indexes
    DROP INDEX IF EXISTS public.idx_summary_main;

    -- Recreate targeted optimized indexes
    CREATE INDEX IF NOT EXISTS idx_summary_ano_filial ON public.data_summary (ano, filial);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_cidade ON public.data_summary (ano, cidade);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_superv ON public.data_summary (ano, superv);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_nome ON public.data_summary (ano, nome);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codfor ON public.data_summary (ano, codfor);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_tipovenda ON public.data_summary (ano, tipovenda);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_codcli ON public.data_summary (ano, codcli);
    CREATE INDEX IF NOT EXISTS idx_summary_ano_ramo ON public.data_summary (ano, ramo);
    
    -- Clients Indexes
    CREATE INDEX IF NOT EXISTS idx_clients_bloqueio_cidade ON public.data_clients (bloqueio, cidade);
    CREATE INDEX IF NOT EXISTS idx_clients_ramo ON public.data_clients (ramo);
    
    -- Cluster for physical ordering (optional, but good for sequential reads on default view)
    -- We cluster by filial as it's a common high-level filter
    CLUSTER public.data_summary USING idx_summary_ano_filial;
    ANALYZE public.data_summary;
    ANALYZE public.data_clients;
    
    RETURN 'Banco de dados otimizado com sucesso! Novos índices (v2) aplicados.';
EXCEPTION WHEN OTHERS THEN
    RETURN 'Erro ao otimizar banco: ' || SQLERRM;
END;
$$;
