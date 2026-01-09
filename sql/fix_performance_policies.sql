
-- ==============================================================================
-- FIX PERFORMANCE WARNINGS: MULTIPLE PERMISSIVE POLICIES
-- Target: public.config_city_branches
-- Issue: Overlapping policies for SELECT action causes performance overhead.
-- ==============================================================================

-- 1. Drop existing overlapping policies
DROP POLICY IF EXISTS "All Access Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Read Access Approved" ON public.config_city_branches;

-- 2. Create consolidated READ policy (Single policy for SELECT)
-- optimized to handle both roles without multiple policy overhead
CREATE POLICY "Read Access" ON public.config_city_branches
    FOR SELECT
    USING (public.is_approved() OR public.is_admin());

-- 3. Create explicit WRITE policies for Admin (Replacing 'FOR ALL')
CREATE POLICY "Insert Admin" ON public.config_city_branches
    FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "Update Admin" ON public.config_city_branches
    FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "Delete Admin" ON public.config_city_branches
    FOR DELETE
    USING (public.is_admin());
