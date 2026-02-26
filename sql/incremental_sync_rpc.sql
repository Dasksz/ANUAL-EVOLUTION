
-- ==============================================================================
-- GRANULAR SYNC FUNCTIONS (Wipe -> Append -> Commit)
-- Resolves HTTP Gateway Timeouts (60s) by splitting large uploads
-- ==============================================================================

-- 1. Begin Sync (Wipe Data)
CREATE OR REPLACE FUNCTION public.begin_sync_chunk(
    p_table_name text,
    p_chunk_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_start_date date;
    v_end_date date;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso negado.'; END IF;

    IF p_table_name NOT IN ('data_detailed', 'data_history') THEN
        RAISE EXCEPTION 'Tabela inválida: %', p_table_name;
    END IF;

    -- Calculate Range (YYYY-MM)
    v_start_date := TO_DATE(p_chunk_key || '-01', 'YYYY-MM-DD');
    v_end_date := v_start_date + interval '1 month';

    -- Wipe existing data for this chunk
    EXECUTE format('
        DELETE FROM public.%I
        WHERE dtped >= $1 AND dtped < $2
    ', p_table_name)
    USING v_start_date, v_end_date;

    -- Invalidate Metadata (Force re-sync if process crashes before Commit)
    DELETE FROM public.data_metadata
    WHERE table_name = p_table_name AND chunk_key = p_chunk_key;
END;
$$;

-- 2. Append Sync (Insert Batch)
CREATE OR REPLACE FUNCTION public.append_sync_chunk(
    p_table_name text,
    p_rows jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso negado.'; END IF;

    IF p_table_name NOT IN ('data_detailed', 'data_history') THEN
        RAISE EXCEPTION 'Tabela inválida: %', p_table_name;
    END IF;

    -- Insert Batch
    EXECUTE format('
        INSERT INTO public.%I (
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, qtvenda_embalagem_master, tipovenda, filial
        )
        SELECT
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, qtvenda_embalagem_master, tipovenda, filial
        FROM jsonb_populate_recordset(null::public.%I, $1)
    ', p_table_name, p_table_name) USING p_rows;
END;
$$;

-- 3. Commit Sync (Update Metadata)
CREATE OR REPLACE FUNCTION public.commit_sync_chunk(
    p_table_name text,
    p_chunk_key text,
    p_hash text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'Acesso negado.'; END IF;

    INSERT INTO public.data_metadata (table_name, chunk_key, chunk_hash, updated_at)
    VALUES (p_table_name, p_chunk_key, p_hash, now())
    ON CONFLICT (table_name, chunk_key)
    DO UPDATE SET chunk_hash = EXCLUDED.chunk_hash, updated_at = now();
END;
$$;
