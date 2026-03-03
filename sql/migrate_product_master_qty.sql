-- Script de Migração: Movendo "Qtde Embalagem Master" das vendas para Produtos

-- Passo 1: Adicionar a nova coluna na tabela de produtos
ALTER TABLE IF EXISTS dim_produtos ADD COLUMN IF NOT EXISTS qtde_embalagem_master numeric DEFAULT 1;

-- Passo 2: Remover as colunas obsoletas das tabelas de vendas
ALTER TABLE IF EXISTS data_detailed DROP COLUMN IF EXISTS qtvenda_embalagem_master CASCADE;
ALTER TABLE IF EXISTS data_history DROP COLUMN IF EXISTS qtvenda_embalagem_master CASCADE;

-- Fim do script

-- Passo 3: Recriar a função append_to_chunk_v2 para não tentar inserir a coluna removida (vale para data_detailed e data_history)
CREATE OR REPLACE FUNCTION public.append_to_chunk_v2(
    p_table_name text,
    p_rows jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    EXECUTE format('
        INSERT INTO public.%I (
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, tipovenda, filial
        )
        SELECT
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, tipovenda, filial
        FROM jsonb_populate_recordset(null::public.%I, $1)
    ', p_table_name, p_table_name) USING p_rows;
END;
$$;

-- Passo 4: Recriar a função sync_chunk_v2 também para sincronia local
CREATE OR REPLACE FUNCTION public.sync_chunk_v2(
    p_table_name text,
    p_chunk_key text,
    p_rows jsonb,
    p_hash text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Delete existing rows for this chunk key (YYYY-MM)
    EXECUTE format('
        DELETE FROM public.%I
        WHERE TO_CHAR(dtped, ''YYYY-MM'') = $1
    ', p_table_name) USING p_chunk_key;

    -- 2. Insert new rows without the dropped column
    EXECUTE format('
        INSERT INTO public.%I (
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, tipovenda, filial
        )
        SELECT
            pedido, codusur, codsupervisor, produto, codfor, codcli, cidade,
            qtvenda, vlvenda, vlbonific, vldevolucao, totpesoliq,
            dtped, dtsaida, posicao, estoqueunit, tipovenda, filial
        FROM jsonb_populate_recordset(null::public.%I, $2)
    ', p_table_name, p_table_name) USING p_chunk_key, p_rows;

    -- 3. Update metadata
    INSERT INTO public.data_metadata (table_name, chunk_key, chunk_hash, updated_at)
    VALUES (p_table_name, p_chunk_key, p_hash, now())
    ON CONFLICT (table_name, chunk_key)
    DO UPDATE SET chunk_hash = EXCLUDED.chunk_hash, updated_at = now();
END;
$$;
