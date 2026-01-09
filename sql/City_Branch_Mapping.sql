
-- ==============================================================================
-- MIGRATION: CONFIG CITY BRANCHES
-- Purpose: Create table to map Cities to Branches, populate from history, 
-- and allow manual maintenance.
-- ==============================================================================

-- 1. Create Table
CREATE TABLE IF NOT EXISTS public.config_city_branches (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    cidade text NOT NULL UNIQUE,
    filial text, -- Can be null initially if new city
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);

-- 2. Enable RLS
ALTER TABLE public.config_city_branches ENABLE ROW LEVEL SECURITY;

-- 3. Policies
-- Read: Approved Users (Worker needs to read it)
CREATE POLICY "Read Access Approved" ON public.config_city_branches 
FOR SELECT USING (public.is_approved());

-- Write: Admin Only
CREATE POLICY "All Access Admin" ON public.config_city_branches 
FOR ALL USING (public.is_admin());

-- 4. Initial Population Script (Idempotent)
-- Logic: Find the latest sale for each city and use that branch.
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Iterate over distinct cities found in history and detailed
    FOR r IN 
        WITH all_sales AS (
            SELECT cidade, filial, dtped FROM public.data_detailed
            UNION ALL
            SELECT cidade, filial, dtped FROM public.data_history
        ),
        ranked_sales AS (
            SELECT 
                cidade, 
                filial,
                ROW_NUMBER() OVER (PARTITION BY cidade ORDER BY dtped DESC) as rn
            FROM all_sales
            WHERE cidade IS NOT NULL AND cidade != '' AND filial IS NOT NULL
        )
        SELECT DISTINCT cidade, filial 
        FROM ranked_sales 
        WHERE rn = 1
    LOOP
        -- Insert if not exists
        INSERT INTO public.config_city_branches (cidade, filial)
        VALUES (r.cidade, r.filial)
        ON CONFLICT (cidade) DO NOTHING;
    END LOOP;
END $$;
