-- Migration: Removendo o controle de estoque duplicado da tabela data_detailed
-- Isso remove as colunas que não usaremos mais após migrar o estoque para a dim_produtos

-- Apenas execute esse SQL APÓS ter modificado a função `get_innovations_data` e o `worker.js`,
-- e após subir a nova versão do sistema.

-- View Drop
DROP VIEW IF EXISTS public.all_sales CASCADE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'data_detailed'
        AND column_name = 'estoqueunit'
    ) THEN
        ALTER TABLE public.data_detailed DROP COLUMN estoqueunit CASCADE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'data_history'
        AND column_name = 'estoqueunit'
    ) THEN
        ALTER TABLE public.data_history DROP COLUMN estoqueunit CASCADE;
    END IF;
END $$;

-- Unified View Recreate
CREATE OR REPLACE VIEW public.all_sales WITH (security_invoker = true) AS
SELECT * FROM public.data_detailed
UNION ALL
SELECT * FROM public.data_history;
