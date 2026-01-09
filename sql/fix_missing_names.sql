-- Fix: Populate Dimension Tables (Robust & Recovery Mode)
-- This script populates the dimension tables to ensure the all_sales view
-- can correctly resolve codes to names.
-- It attempts to read from original tables first, and falls back to cache_filters
-- for recovery if the original name columns were dropped.

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
    v_rows_inserted int;
BEGIN
    -- Check column existence
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='superv') INTO v_has_superv_detailed;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='superv') INTO v_has_superv_history;

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

    -- 2. Vendedores (assuming 'nome' column availability mirrors 'superv')
    -- We'll check 'nome' specifically to be safe
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='nome') THEN
        EXECUTE '
            INSERT INTO public.dim_vendedores (codigo, nome)
            SELECT codusur, MAX(nome)
            FROM public.data_detailed
            WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
            GROUP BY codusur
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='nome') THEN
        EXECUTE '
            INSERT INTO public.dim_vendedores (codigo, nome)
            SELECT codusur, MAX(nome)
            FROM public.data_history
            WHERE codusur IS NOT NULL AND codusur != '''' AND nome IS NOT NULL
            GROUP BY codusur
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    -- 3. Fornecedores (assuming 'fornecedor' column)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_detailed' AND column_name='fornecedor') THEN
        EXECUTE '
            INSERT INTO public.dim_fornecedores (codigo, nome)
            SELECT codfor, MAX(fornecedor)
            FROM public.data_detailed
            WHERE codfor IS NOT NULL AND codfor != '''' AND fornecedor IS NOT NULL
            GROUP BY codfor
            ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;
        ';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='data_history' AND column_name='fornecedor') THEN
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
    -- STRATEGY B: RECOVERY FROM CACHE (If cache_filters has data)
    -- ========================================================================
    -- This runs regardless of Strategy A to catch any missing codes that might exist in cache

    -- 1. Recover Supervisors
    INSERT INTO public.dim_supervisores (codigo, nome)
    SELECT d.codsupervisor, mode() WITHIN GROUP (ORDER BY c.superv) as recovered_name
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
    ON CONFLICT (codigo) DO NOTHING; -- Do not overwrite existing (likely better) data

    -- 2. Recover Vendedores
    INSERT INTO public.dim_vendedores (codigo, nome)
    SELECT d.codusur, mode() WITHIN GROUP (ORDER BY c.nome) as recovered_name
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

    -- 3. Recover Fornecedores (Direct from cache is easiest as codfor is in cache)
    INSERT INTO public.dim_fornecedores (codigo, nome)
    SELECT DISTINCT codfor, fornecedor
    FROM public.cache_filters
    WHERE codfor IS NOT NULL AND codfor != ''
      AND fornecedor IS NOT NULL AND fornecedor != ''
    ON CONFLICT (codigo) DO NOTHING;

END $$;

-- 5. Refresh the summary cache to apply changes
SELECT refresh_cache_summary();
