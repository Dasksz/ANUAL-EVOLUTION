-- Fix: Populate Dimension Tables
-- This script populates the dimension tables to ensure the all_sales view
-- can correctly resolve codes to names.

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
-- Please ensure you run the security setup from your optimization plan if these tables were just created.

-- 2. Populate Supervisores
INSERT INTO public.dim_supervisores (codigo, nome)
SELECT codsupervisor, MAX(superv)
FROM public.data_detailed
WHERE codsupervisor IS NOT NULL AND codsupervisor != '' AND superv IS NOT NULL
GROUP BY codsupervisor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_supervisores (codigo, nome)
SELECT codsupervisor, MAX(superv)
FROM public.data_history
WHERE codsupervisor IS NOT NULL AND codsupervisor != '' AND superv IS NOT NULL
GROUP BY codsupervisor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

-- 3. Populate Vendedores
INSERT INTO public.dim_vendedores (codigo, nome)
SELECT codusur, MAX(nome)
FROM public.data_detailed
WHERE codusur IS NOT NULL AND codusur != '' AND nome IS NOT NULL
GROUP BY codusur
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_vendedores (codigo, nome)
SELECT codusur, MAX(nome)
FROM public.data_history
WHERE codusur IS NOT NULL AND codusur != '' AND nome IS NOT NULL
GROUP BY codusur
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

-- 4. Populate Fornecedores
INSERT INTO public.dim_fornecedores (codigo, nome)
SELECT codfor, MAX(fornecedor)
FROM public.data_detailed
WHERE codfor IS NOT NULL AND codfor != '' AND fornecedor IS NOT NULL
GROUP BY codfor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_fornecedores (codigo, nome)
SELECT codfor, MAX(fornecedor)
FROM public.data_history
WHERE codfor IS NOT NULL AND codfor != '' AND fornecedor IS NOT NULL
GROUP BY codfor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

-- 5. Refresh the summary cache to apply changes
SELECT refresh_cache_summary();
