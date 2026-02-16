-- ==============================================================================
-- FIX SYNC ERRORS (AMBIGUOUS COLUMN + BATCH PERFORMANCE)
-- ==============================================================================

-- 1. Ensure columns exist (Idempotent)
ALTER TABLE public.data_detailed ADD COLUMN IF NOT EXISTS row_hash text;
ALTER TABLE public.data_history ADD COLUMN IF NOT EXISTS row_hash text;
ALTER TABLE public.data_clients ADD COLUMN IF NOT EXISTS row_hash text;

-- 2. Create Hash Indexes (High Performance Lookup)
CREATE INDEX IF NOT EXISTS idx_detailed_hash ON public.data_detailed (row_hash);
CREATE INDEX IF NOT EXISTS idx_history_hash ON public.data_history (row_hash);
CREATE INDEX IF NOT EXISTS idx_clients_hash ON public.data_clients (row_hash);

-- 3. Fix RPC Ambiguity: Rename output column to 'hash'
-- DROP FUNCTION IF EXISTS public.get_table_hashes(text); -- Explicit drop if signature changes

CREATE OR REPLACE FUNCTION public.get_table_hashes(p_table_name text)
RETURNS TABLE (hash text) -- Renamed from row_hash to avoid PL/pgSQL ambiguity
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security Check
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Acesso negado. Apenas administradores podem sincronizar dados.';
    END IF;

    IF p_table_name = 'data_detailed' THEN
        RETURN QUERY SELECT t.row_hash FROM public.data_detailed t WHERE t.row_hash IS NOT NULL;
    ELSIF p_table_name = 'data_history' THEN
        RETURN QUERY SELECT t.row_hash FROM public.data_history t WHERE t.row_hash IS NOT NULL;
    ELSIF p_table_name = 'data_clients' THEN
        RETURN QUERY SELECT t.row_hash FROM public.data_clients t WHERE t.row_hash IS NOT NULL;
    ELSE
        RAISE EXCEPTION 'Tabela inválida: %', p_table_name;
    END IF;
END;
$$;

-- 4. Recreate Delete Function (Safety)
CREATE OR REPLACE FUNCTION public.delete_by_hashes(p_table_name text, p_hashes text[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security Check
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Acesso negado.';
    END IF;

    IF p_table_name = 'data_detailed' THEN
        DELETE FROM public.data_detailed WHERE row_hash = ANY(p_hashes);
    ELSIF p_table_name = 'data_history' THEN
        DELETE FROM public.data_history WHERE row_hash = ANY(p_hashes);
    ELSIF p_table_name = 'data_clients' THEN
        DELETE FROM public.data_clients WHERE row_hash = ANY(p_hashes);
    ELSE
        RAISE EXCEPTION 'Tabela inválida: %', p_table_name;
    END IF;
END;
$$;

-- 5. Ensure is_admin avoids recursion issues (Standard definition)
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  -- Direct query on profiles using SECURITY DEFINER bypasses RLS on profiles if owned by postgres
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND role = 'adm');
END;
$$ LANGUAGE plpgsql;
