-- Fix performance warnings by consolidating policies

-- 1. Config City Branches
DROP POLICY IF EXISTS "All Access Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Delete Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Delete Access Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Insert Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Read Access" ON public.config_city_branches;
DROP POLICY IF EXISTS "Read Access Approved" ON public.config_city_branches;
DROP POLICY IF EXISTS "Update Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Write Access Admin" ON public.config_city_branches;
DROP POLICY IF EXISTS "Update Access Admin" ON public.config_city_branches;

CREATE POLICY "Unified Read Access" ON public.config_city_branches FOR SELECT USING (public.is_admin() OR public.is_approved());
CREATE POLICY "Admin Insert" ON public.config_city_branches FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "Admin Update" ON public.config_city_branches FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "Admin Delete" ON public.config_city_branches FOR DELETE USING (public.is_admin());

-- 2. Dimension Tables
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['dim_fornecedores', 'dim_supervisores', 'dim_vendedores'])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "All Access Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Delete Access Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Delete Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Insert Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Admin" ON public.%I', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access" ON public.%I', t);

        -- Recreate Unified Read
        EXECUTE format('CREATE POLICY "Unified Read Access" ON public.%I FOR SELECT USING (public.is_admin() OR public.is_approved())', t);

        -- Recreate Admin Write
        EXECUTE format('CREATE POLICY "Admin Insert" ON public.%I FOR INSERT WITH CHECK (public.is_admin())', t);
        EXECUTE format('CREATE POLICY "Admin Update" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin())', t);
        EXECUTE format('CREATE POLICY "Admin Delete" ON public.%I FOR DELETE USING (public.is_admin())', t);
    END LOOP;
END $$;

-- 3. Fix Security Definer View warnings (Force Security Invoker)
ALTER VIEW public.all_sales SET (security_invoker = true);
ALTER VIEW public.view_data_detailed_completa SET (security_invoker = true);
ALTER VIEW public.view_data_history_completa SET (security_invoker = true);
