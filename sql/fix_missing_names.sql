-- Fix: Populate Dimension Tables (Robust, Optimized & Delta Recovery)
-- This script populates the dimension tables to ensure the all_sales view
-- can correctly resolve codes to names.
-- It attempts to read from original tables first, and falls back to cache_filters
-- for recovery ONLY for missing codes.

SET statement_timeout = '3600s'; -- Increase timeout to 1 hour

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
    -- This is fast. We do this first.

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
    -- STRATEGY B: DELTA RECOVERY FROM CACHE
    -- ========================================================================
    -- Only recover codes that are STILL missing from the dimensions.
    -- This prevents processing millions of rows for codes we already found.

    -- 1. Recover Supervisors (Only missing ones)
    IF EXISTS (
        SELECT 1 FROM (
            SELECT codsupervisor FROM public.data_detailed
            UNION
            SELECT codsupervisor FROM public.data_history
        ) t
        WHERE t.codsupervisor NOT IN (SELECT codigo FROM public.dim_supervisores)
    ) THEN
        INSERT INTO public.dim_supervisores (codigo, nome)
        SELECT d.codsupervisor, MAX(c.superv)
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
          -- OPTIMIZATION: ONLY LOOK FOR MISSING CODES
          AND d.codsupervisor NOT IN (SELECT codigo FROM public.dim_supervisores)
          AND c.superv IS NOT NULL AND c.superv != ''
        GROUP BY d.codsupervisor
        ON CONFLICT (codigo) DO NOTHING;
    END IF;

    -- 2. Recover Vendedores (Only missing ones)
    IF EXISTS (
        SELECT 1 FROM (
            SELECT codusur FROM public.data_detailed
            UNION
            SELECT codusur FROM public.data_history
        ) t
        WHERE t.codusur NOT IN (SELECT codigo FROM public.dim_vendedores)
    ) THEN
        INSERT INTO public.dim_vendedores (codigo, nome)
        SELECT d.codusur, MAX(c.nome)
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
          -- OPTIMIZATION: ONLY LOOK FOR MISSING CODES
          AND d.codusur NOT IN (SELECT codigo FROM public.dim_vendedores)
          AND c.nome IS NOT NULL AND c.nome != ''
        GROUP BY d.codusur
        ON CONFLICT (codigo) DO NOTHING;
    END IF;

    -- 3. Recover Fornecedores
    INSERT INTO public.dim_fornecedores (codigo, nome)
    SELECT DISTINCT codfor, fornecedor
    FROM public.cache_filters
    WHERE codfor IS NOT NULL AND codfor != ''
      AND fornecedor IS NOT NULL AND fornecedor != ''
      AND codfor NOT IN (SELECT codigo FROM public.dim_fornecedores)
    ON CONFLICT (codigo) DO NOTHING;

END $$;

-- IMPORTANT: Please run the following command separately to refresh the dashboard:
-- SELECT refresh_cache_summary();
