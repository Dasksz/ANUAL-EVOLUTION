-- Fix: Populate Dimension Tables (Robust & Recovery Mode)
-- This script populates the dimension tables to ensure the all_sales view
-- can correctly resolve codes to names.
-- It attempts to read from original tables first, and falls back to cache_filters
-- for recovery if the original name columns were dropped.

SET statement_timeout = '1200s'; -- Increase timeout to 20 minutes

-- 1. Creates dimension tables if they don't exist
CREATE TABLE IF NOT EXISTS public.dim_supervisores (
    codigo text PRIMARY KEY,
    nome text
);

CREATE TABLE IF NOT EXISTS public.dim_vendedores (
    codigo text PRIMARY KEY,
    nome text
);

CREATE TABLE IF NOT EXISTS public.dim_fornecedores (
    codigo text PRIMARY KEY,
    nome text
);

-- Note: RLS policies are skipped in this fix script to avoid dependency issues.

DO $$
DECLARE
    v_has_superv_detailed boolean;
    v_has_superv_history boolean;
    v_has_nome_detailed boolean;
    v_has_nome_history boolean;
    v_has_fornecedor_detailed boolean;
    v_has_fornecedor_history boolean;
BEGIN
    -- Check column existence
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='superv') INTO v_has_superv_detailed;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='superv') INTO v_has_superv_history;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='nome') INTO v_has_nome_detailed;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='nome') INTO v_has_nome_history;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='fornecedor') INTO v_has_fornecedor_detailed;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='fornecedor') INTO v_has_fornecedor_history;

    -- ========================================================================
    -- STRATEGY A: DIRECT POPULATION (If columns exist)
    -- ========================================================================

    -- 1. Supervisores
    IF v_has_superv_detailed THEN
        EXECUTE '
            INSERT INTO public.dim_supervisores (codigo, nome)
            SELECT codsupervisor, MAX(superv)
            FROM public.data_detailed
            WHERE codsupervisor IS NOT NULL AND codsupervisor != '''' AND superv IS NOT NULL
            GROUP BY codsupervisor
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    IF v_has_superv_history THEN
        EXECUTE '
            INSERT INTO public.dim_supervisores (codigo, nome)
            SELECT codsupervisor, MAX(superv)
            FROM public.data_history
            WHERE codsupervisor IS NOT NULL AND codsupervisor != '''' AND superv IS NOT NULL
            GROUP BY codsupervisor
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    -- 2. Vendedores
    IF v_has_nome_detailed THEN
        EXECUTE '
            INSERT INTO public.dim_vendedores (codigo, nome)
            SELECT codusur, MAX(nome)
            FROM public.data_detailed
            WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
            GROUP BY codusur
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    IF v_has_nome_history THEN
        EXECUTE '
            INSERT INTO public.dim_vendedores (codigo, nome)
            SELECT codusur, MAX(nome)
            FROM public.data_history
            WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
            GROUP BY codusur
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    -- 3. Fornecedores
    IF v_has_fornecedor_detailed THEN
        EXECUTE '
            INSERT INTO public.dim_fornecedores (codigo, nome)
            SELECT codfor, MAX(fornecedor)
            FROM public.data_detailed
            WHERE codfor IS NOT NULL AND codfor != '''' AND fornecedor IS NOT NULL
            GROUP BY codfor
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    IF v_has_fornecedor_history THEN
        EXECUTE '
            INSERT INTO public.dim_fornecedores (codigo, nome)
            SELECT codfor, MAX(fornecedor)
            FROM public.data_history
            WHERE codfor IS NOT NULL AND codfor != '''' AND fornecedor IS NOT NULL
            GROUP BY codfor
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    -- ========================================================================
    -- STRATEGY B: RECOVERY FROM CACHE (Only if columns missing)
    -- ========================================================================
    -- This join is expensive, so we only run it if we couldn't use Strategy A for any table

    -- 1. Recover Supervisors
    IF (NOT v_has_superv_detailed) OR (NOT v_has_superv_history) THEN
        INSERT INTO public.dim_supervisores (codigo, nome)
        SELECT d.codsupervisor, MAX(c.superv) as recovered_name
        FROM (
            SELECT codsupervisor, filial, cidade, codfor, tipovenda, dtped FROM public.data_detailed
            UNION ALL
            SELECT codsupervisor, filial, cidade, codfor, tipovenda, dtped FROM public.data_history
        ) d
        JOIN public.cache_filters c
          ON d.filial = c.filial
          AND d.cidade = c.cidade
          AND EXTRACT(YEAR FROM d.dtped)::int = c.ano
          AND EXTRACT(MONTH FROM d.dtped)::int = c.mes
          AND d.codfor = c.codfor
          AND d.tipovenda = c.tipovenda
        WHERE d.codsupervisor IS NOT NULL AND d.codsupervisor != ''
          AND c.superv IS NOT NULL AND c.superv != ''
        GROUP BY d.codsupervisor
        ON CONFLICT (codigo) DO NOTHING;
    END IF;

    -- 2. Recover Vendedores
    IF (NOT v_has_nome_detailed) OR (NOT v_has_nome_history) THEN
        INSERT INTO public.dim_vendedores (codigo, nome)
        SELECT d.codusur, MAX(c.nome) as recovered_name
        FROM (
            SELECT codusur, filial, cidade, codfor, tipovenda, dtped FROM public.data_detailed
            UNION ALL
            SELECT codusur, filial, cidade, codfor, tipovenda, dtped FROM public.data_history
        ) d
        JOIN public.cache_filters c
          ON d.filial = c.filial
          AND d.cidade = c.cidade
          AND EXTRACT(YEAR FROM d.dtped)::int = c.ano
          AND EXTRACT(MONTH FROM d.dtped)::int = c.mes
          AND d.codfor = c.codfor
          AND d.tipovenda = c.tipovenda
        WHERE d.codusur IS NOT NULL AND d.codusur != ''
          AND c.nome IS NOT NULL AND c.nome != ''
        GROUP BY d.codusur
        ON CONFLICT (codigo) DO NOTHING;
    END IF;

    -- 3. Recover Fornecedores
    -- Safe to run always as it is fast (no big join)
    IF (NOT v_has_fornecedor_detailed) OR (NOT v_has_fornecedor_history) THEN
        INSERT INTO public.dim_fornecedores (codigo, nome)
        SELECT DISTINCT codfor, fornecedor
        FROM public.cache_filters
        WHERE codfor IS NOT NULL AND codfor != ''
          AND fornecedor IS NOT NULL AND fornecedor != ''
        ON CONFLICT (codigo) DO NOTHING;
    END IF;

END $$;

-- 5. Refresh the summary cache to apply changes
SELECT refresh_cache_summary();
