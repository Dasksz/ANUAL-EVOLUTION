
-- ==============================================================================
-- FIX SUPABASE WARNINGS & SECURITY CLEANUP
-- ==============================================================================

-- 1. DROP DUPLICATE INDEXES
-- These indexes are redundant (identical to existing ones) and slow down writes.

DROP INDEX IF EXISTS public.idx_cache_filters_fornecedor_col;
DROP INDEX IF EXISTS public.idx_detailed_cidade_btree;
DROP INDEX IF EXISTS public.idx_detailed_filial_btree;
DROP INDEX IF EXISTS public.idx_detailed_nome_btree;
DROP INDEX IF EXISTS public.idx_detailed_superv_btree;
DROP INDEX IF EXISTS public.idx_history_cidade_btree;
DROP INDEX IF EXISTS public.idx_history_filial_btree;
DROP INDEX IF EXISTS public.idx_history_nome_btree;
DROP INDEX IF EXISTS public.idx_history_superv_btree;

-- 2. FIX RLS INITIALIZATION PLAN (PERFORMANCE)
-- Wrap auth.uid() in (select ...) to prevent per-row re-evaluation.

-- Fix 'Users can insert their own profile'
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT
WITH CHECK ((select auth.uid()) = id);

-- Fix 'Users can update own profile'
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE
USING ((select auth.uid()) = id)
WITH CHECK ((select auth.uid()) = id);

-- Fix 'Profiles Visibility'
DROP POLICY IF EXISTS "Profiles Visibility" ON public.profiles;
CREATE POLICY "Profiles Visibility" ON public.profiles FOR SELECT
USING (
  (select auth.uid()) = id
  OR public.is_admin()
);


-- 3. REMOVE CONFLICTING PERMISSIVE POLICIES
-- The warnings indicate policies like "Enable access for all users" exist alongside secure policies.
-- These likely allow 'anon' access or full access, undermining the security model.

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles')
    LOOP
        -- Drop the specific insecure default policies mentioned in warnings
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);

        -- Profiles specifically
        IF t = 'profiles' THEN
             EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
        END IF;
    END LOOP;
END $$;
