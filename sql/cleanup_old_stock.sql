-- Migration: Removendo o controle de estoque duplicado da tabela data_detailed
-- Isso remove as colunas que não usaremos mais após migrar o estoque para a dim_produtos

-- Apenas execute esse SQL APÓS ter modificado a função `get_innovations_data` e o `worker.js`,
-- e após subir a nova versão do sistema.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'data_detailed'
        AND column_name = 'estoqueunit'
    ) THEN
        ALTER TABLE public.data_detailed DROP COLUMN estoqueunit;
    END IF;
END $$;
