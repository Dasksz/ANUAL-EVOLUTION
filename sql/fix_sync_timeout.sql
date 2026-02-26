
-- OTIMIZAÇÃO DE SYNC (FIX TIMEOUT)
-- Substitui a exclusão em lote (loop) por um DELETE direto usando índice de data.

CREATE OR REPLACE FUNCTION public.sync_sales_chunk(
    p_table_name text,
    p_chunk_key text,
    p_rows jsonb,
    p_hash text
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

    SET LOCAL statement_timeout = '600s'; -- 10 minutes timeout

    -- 1. Validate Table
    IF p_table_name NOT IN ('data_detailed', 'data_history') THEN
        RAISE EXCEPTION 'Tabela inválida: %', p_table_name;
    END IF;

    -- 2. Calculate Date Range from Chunk Key (YYYY-MM) for Index Optimization
    -- Using TO_DATE and Range allows Postgres to use the dtped index instead of full scan
    v_start_date := TO_DATE(p_chunk_key || '-01', 'YYYY-MM-DD');
    v_end_date := v_start_date + interval '1 month';

    -- 3. Delete Existing Data for this Chunk (Optimized: Single efficient DELETE)
    -- Replaces batch loop which caused timeouts.
    -- Uses dtped index for fast range deletion.
    EXECUTE format('
        DELETE FROM public.%I
        WHERE dtped >= $1 AND dtped < $2
    ', p_table_name)
    USING v_start_date, v_end_date;

    -- 4. Insert New Data
    -- We assume p_rows is an array of objects. We use json_populate_recordset.
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

    -- 5. Update Metadata
    INSERT INTO public.data_metadata (table_name, chunk_key, chunk_hash, updated_at)
    VALUES (p_table_name, p_chunk_key, p_hash, now())
    ON CONFLICT (table_name, chunk_key)
    DO UPDATE SET chunk_hash = EXCLUDED.chunk_hash, updated_at = now();

END;
$$;
