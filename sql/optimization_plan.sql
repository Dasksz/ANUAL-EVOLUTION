-- ==============================================================================
-- OPTIMIZATION PLAN SCRIPT
-- Phase 1: Indexes
-- Phase 2: Normalization (Dimensions & Column Drops)
-- Phase 3: Compatibility Views & Updated RPCs
-- Phase 4: Vacuum (Manual execution recommended)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PHASE 1: REMOVE FAT INDEXES & CREATE LEAN ONES
-- ------------------------------------------------------------------------------

DROP INDEX IF EXISTS public.idx_history_dtped_composite;
DROP INDEX IF EXISTS public.idx_detailed_dtped_composite;
DROP INDEX IF EXISTS public.idx_detailed_cidade_btree;
DROP INDEX IF EXISTS public.idx_detailed_filial_btree;
DROP INDEX IF EXISTS public.idx_detailed_nome_btree;
DROP INDEX IF EXISTS public.idx_detailed_superv_btree;
DROP INDEX IF EXISTS public.idx_history_cidade_btree;
DROP INDEX IF EXISTS public.idx_history_filial_btree;
DROP INDEX IF EXISTS public.idx_history_nome_btree;
DROP INDEX IF EXISTS public.idx_history_superv_btree;

-- Create lean indexes (Lego Strategy)
CREATE INDEX IF NOT EXISTS idx_history_dtped ON public.data_history (dtped);
CREATE INDEX IF NOT EXISTS idx_history_filial ON public.data_history (filial);
CREATE INDEX IF NOT EXISTS idx_history_codfor ON public.data_history (codfor);
CREATE INDEX IF NOT EXISTS idx_history_codusur ON public.data_history (codusur);
CREATE INDEX IF NOT EXISTS idx_history_codsupervisor ON public.data_history (codsupervisor);
CREATE INDEX IF NOT EXISTS idx_history_produto ON public.data_history (produto);

CREATE INDEX IF NOT EXISTS idx_detailed_dtped ON public.data_detailed (dtped);
CREATE INDEX IF NOT EXISTS idx_detailed_filial ON public.data_detailed (filial);
CREATE INDEX IF NOT EXISTS idx_detailed_codfor ON public.data_detailed (codfor);
CREATE INDEX IF NOT EXISTS idx_detailed_codusur ON public.data_detailed (codusur);
CREATE INDEX IF NOT EXISTS idx_detailed_codsupervisor ON public.data_detailed (codsupervisor);
CREATE INDEX IF NOT EXISTS idx_detailed_produto ON public.data_detailed (produto);

-- ------------------------------------------------------------------------------
-- PHASE 2: NORMALIZATION (DIMENSIONS)
-- ------------------------------------------------------------------------------

-- 2.1 Create Dimension Tables
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

-- Enable RLS for Dimensions
ALTER TABLE public.dim_supervisores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dim_vendedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dim_fornecedores ENABLE ROW LEVEL SECURITY;

-- Create Policies for Dimensions
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('dim_supervisores', 'dim_vendedores', 'dim_fornecedores')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Read Access Approved" ON public.%I FOR SELECT USING (public.is_approved());', t);

        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Write Access Admin" ON public.%I FOR INSERT WITH CHECK (public.is_admin());', t);

        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I;', t);
        EXECUTE format('CREATE POLICY "Update Access Admin" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());', t);
    END LOOP;
END $$;


-- 2.2 Populate Dimensions from Existing Data (Migration)
-- Supervisors
INSERT INTO public.dim_supervisores (codigo, nome)
SELECT codsupervisor, MAX(superv)
FROM public.data_history
WHERE codsupervisor IS NOT NULL AND codsupervisor != '' AND superv IS NOT NULL
GROUP BY codsupervisor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_supervisores (codigo, nome)
SELECT codsupervisor, MAX(superv)
FROM public.data_detailed
WHERE codsupervisor IS NOT NULL AND codsupervisor != '' AND superv IS NOT NULL
GROUP BY codsupervisor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

-- Vendors
INSERT INTO public.dim_vendedores (codigo, nome)
SELECT codusur, MAX(nome)
FROM public.data_history
WHERE codusur IS NOT NULL AND codusur != '' AND nome IS NOT NULL
GROUP BY codusur
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_vendedores (codigo, nome)
SELECT codusur, MAX(nome)
FROM public.data_detailed
WHERE codusur IS NOT NULL AND codusur != '' AND nome IS NOT NULL
GROUP BY codusur
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

-- Suppliers
INSERT INTO public.dim_fornecedores (codigo, nome)
SELECT codfor, MAX(fornecedor)
FROM public.data_history
WHERE codfor IS NOT NULL AND codfor != '' AND fornecedor IS NOT NULL
GROUP BY codfor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;

INSERT INTO public.dim_fornecedores (codigo, nome)
SELECT codfor, MAX(fornecedor)
FROM public.data_detailed
WHERE codfor IS NOT NULL AND codfor != '' AND fornecedor IS NOT NULL
GROUP BY codfor
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome;


-- 2.3 Update RPCs to Use Dimensions (BEFORE Dropping Columns)
-- We need to update refresh_cache_filters and refresh_cache_summary to JOIN dimensions

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
        s.nome as superv,
        COALESCE(v.nome, c.nomecliente) as nome,
        t.codfor,
        f.nome as fornecedor,
        t.tipovenda,
        t.yr,
        t.mth
    FROM (
        SELECT filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_detailed
        UNION ALL
        SELECT filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli,
               EXTRACT(YEAR FROM dtped)::int as yr, EXTRACT(MONTH FROM dtped)::int as mth
        FROM public.data_history
    ) t
    LEFT JOIN public.data_clients c ON t.codcli = c.codigo_cliente
    LEFT JOIN public.dim_supervisores s ON t.codsupervisor = s.codigo
    LEFT JOIN public.dim_vendedores v ON t.codusur = v.codigo
    LEFT JOIN public.dim_fornecedores f ON t.codfor = f.codigo;
END;
$$;


CREATE OR REPLACE FUNCTION refresh_cache_summary()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    SET LOCAL statement_timeout = '600s';

    TRUNCATE TABLE public.data_summary;

    INSERT INTO public.data_summary (
        ano, mes, filial, cidade, superv, nome, codfor, tipovenda, codcli,
        vlvenda, peso, bonificacao, devolucao,
        mix_produtos, mix_details,
        pre_mix_count, pre_positivacao_val
    )
    WITH raw_data AS (
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_detailed
        UNION ALL
        SELECT dtped, filial, cidade, codsupervisor, codusur, codfor, tipovenda, codcli, vlvenda, totpesoliq, vlbonific, vldevolucao, produto
        FROM public.data_history
    ),
    augmented_data AS (
        SELECT
            EXTRACT(YEAR FROM s.dtped)::int as ano,
            EXTRACT(MONTH FROM s.dtped)::int as mes,
            s.filial,
            COALESCE(s.cidade, c.cidade) as cidade,
            sup.nome as superv,
            COALESCE(vend.nome, c.nomecliente) as nome,
            s.codfor,
            s.tipovenda,
            s.codcli,
            s.vlvenda, s.totpesoliq, s.vlbonific, s.vldevolucao, s.produto
        FROM raw_data s
        LEFT JOIN public.data_clients c ON s.codcli = c.codigo_cliente
        LEFT JOIN public.dim_supervisores sup ON s.codsupervisor = sup.codigo
        LEFT JOIN public.dim_vendedores vend ON s.codusur = vend.codigo
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
        (SELECT COUNT(*) FROM jsonb_each_text(json_prod) WHERE (value)::numeric >= 1 AND codfor IN ('707', '708')) as mix_calc,
        CASE WHEN total_val >= 1 THEN 1 ELSE 0 END as pos_calc
    FROM client_agg;

    CLUSTER public.data_summary USING idx_summary_ano_mes_filial;
    ANALYZE public.data_summary;
END;
$$;


-- 2.4 Drop Columns (The Diet)
-- Drop dependent view first to avoid 2BP01 error
DROP VIEW IF EXISTS public.all_sales;

ALTER TABLE public.data_history DROP COLUMN IF EXISTS superv;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS nome;
ALTER TABLE public.data_history DROP COLUMN IF EXISTS fornecedor;

ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS superv;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS nome;
ALTER TABLE public.data_detailed DROP COLUMN IF EXISTS fornecedor;


-- ------------------------------------------------------------------------------
-- PHASE 3: COMPATIBILITY VIEWS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.view_data_history_completa AS
SELECT
    h.*,
    s.nome as superv,
    v.nome as nome, -- nome do vendedor
    f.nome as fornecedor
FROM public.data_history h
LEFT JOIN public.dim_supervisores s ON h.codsupervisor = s.codigo
LEFT JOIN public.dim_vendedores v ON h.codusur = v.codigo
LEFT JOIN public.dim_fornecedores f ON h.codfor = f.codigo;

CREATE OR REPLACE VIEW public.view_data_detailed_completa AS
SELECT
    h.*,
    s.nome as superv,
    v.nome as nome, -- nome do vendedor
    f.nome as fornecedor
FROM public.data_detailed h
LEFT JOIN public.dim_supervisores s ON h.codsupervisor = s.codigo
LEFT JOIN public.dim_vendedores v ON h.codusur = v.codigo
LEFT JOIN public.dim_fornecedores f ON h.codfor = f.codigo;

-- Recreate all_sales view using compatibility views (Restores full schema)
CREATE OR REPLACE VIEW public.all_sales AS
SELECT * FROM public.view_data_detailed_completa
UNION ALL
SELECT * FROM public.view_data_history_completa;


-- ------------------------------------------------------------------------------
-- PHASE 4: CLEANUP & CACHE REFRESH
-- ------------------------------------------------------------------------------
-- VACUUM FULL VERBOSE public.data_history;
-- VACUUM FULL VERBOSE public.data_detailed;

-- Force PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';
