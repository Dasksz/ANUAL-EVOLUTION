-- ==============================================================================
-- DATABASE OPTIMIZATIONS (Proposals 2, 3 and 4)
-- ==============================================================================

-- 1. PROPOSTA 2: Remoção de colunas `id` (UUIDs) das tabelas massivas
DO $$
BEGIN
    -- Remove id from data_detailed if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'id') THEN
        ALTER TABLE public.data_detailed DROP COLUMN id;
    END IF;

    -- Remove id from data_history if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'id') THEN
        ALTER TABLE public.data_history DROP COLUMN id;
    END IF;
END $$;

-- 2. PROPOSTA 3: Remoção de colunas operacionais inúteis (created_at e posicao)
DO $$
BEGIN
    -- Remove from data_detailed
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'created_at') THEN
        ALTER TABLE public.data_detailed DROP COLUMN created_at;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_detailed' AND column_name = 'posicao') THEN
        ALTER TABLE public.data_detailed DROP COLUMN posicao;
    END IF;

    -- Remove from data_history
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'created_at') THEN
        ALTER TABLE public.data_history DROP COLUMN created_at;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'data_history' AND column_name = 'posicao') THEN
        ALTER TABLE public.data_history DROP COLUMN posicao;
    END IF;
END $$;

-- 3. PROPOSTA 4: Otimização de Índices (Substituição de B-Trees por BRIN na coluna dtped)

-- Drop existing normal B-Tree indexes on dtped to avoid conflict/redundancy
DROP INDEX IF EXISTS public.idx_data_detailed_dtped;
DROP INDEX IF EXISTS public.idx_data_history_dtped;

-- Create BRIN indexes for time ranges, which uses minimal disk space for date fields in ordered tables
CREATE INDEX IF NOT EXISTS idx_data_detailed_dtped_brin ON public.data_detailed USING brin (dtped);
CREATE INDEX IF NOT EXISTS idx_data_history_dtped_brin ON public.data_history USING brin (dtped);
