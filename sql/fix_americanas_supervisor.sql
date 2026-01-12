
-- Migration Script: Fix Americanas Supervisor Code
-- 1. Updates historical and detailed data to use 'SV_AMERICANAS' as supervisor code for Americanas sales.
-- 2. Corrects dim_supervisores to ensure code '8' is BALCAO and 'SV_AMERICANAS' is SV AMERICANAS.

BEGIN;

-- Update data_detailed
UPDATE public.data_detailed
SET codsupervisor = 'SV_AMERICANAS'
WHERE codusur = 'AMERICANAS';

-- Update data_history
UPDATE public.data_history
SET codsupervisor = 'SV_AMERICANAS'
WHERE codusur = 'AMERICANAS';

-- Fix dim_supervisores
-- Ensure code 8 is BALCAO
INSERT INTO public.dim_supervisores (codigo, nome) VALUES ('8', 'BALCAO')
ON CONFLICT (codigo) DO UPDATE SET nome = 'BALCAO';

-- Ensure code SV_AMERICANAS exists
INSERT INTO public.dim_supervisores (codigo, nome) VALUES ('SV_AMERICANAS', 'SV AMERICANAS')
ON CONFLICT (codigo) DO UPDATE SET nome = 'SV AMERICANAS';

-- Refresh Cache to reflect changes
SELECT refresh_cache_summary();

COMMIT;
