-- Script para remover colunas e índices de hash legados das tabelas de vendas
-- Execute este script no Editor SQL do Supabase para limpar as colunas antigas.

DO $$
BEGIN
    -- 1. Remover índices de hash das tabelas de vendas
    DROP INDEX IF EXISTS public.idx_detailed_hash;
    DROP INDEX IF EXISTS public.idx_history_hash;

    -- 2. Remover coluna row_hash da tabela data_detailed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'row_hash') THEN
        ALTER TABLE public.data_detailed DROP COLUMN row_hash;
    END IF;

    -- 3. Remover coluna row_hash da tabela data_history
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'row_hash') THEN
        ALTER TABLE public.data_history DROP COLUMN row_hash;
    END IF;

    -- Nota: A tabela data_clients DEVE manter a coluna row_hash para a sincronização granular.
END $$;
