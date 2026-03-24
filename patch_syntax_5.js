const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const target1 = `-- Clean up Insecure Policies
DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_clients', 'data_detailed', 'data_history', 'profiles', 'data_summary', 'data_summary_frequency', 'cache_filters', 'data_holidays', 'config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Enable access for all users" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access Approved" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Write Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Delete Access Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "All Access Admin" ON public.%I;', t);
        -- Drop obsolete policies causing performance warnings
        EXECUTE format('DROP POLICY IF EXISTS "Delete Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Insert Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Update Admin" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Read Access" ON public.%I;', t);

        -- New standardized policy names
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I;', t);
        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I;', t);
    END LOOP;
END $$;`;

let new1 = `-- Clean up Insecure Policies\n`;
const tables1 = ['data_clients', 'data_detailed', 'data_history', 'profiles', 'data_summary', 'data_summary_frequency', 'cache_filters', 'data_holidays', 'config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores'];
tables1.forEach(t => {
    new1 += `DROP POLICY IF EXISTS "Enable access for all users" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Read Access Approved" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Write Access Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Update Access Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Delete Access Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "All Access Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Delete Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Insert Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Update Admin" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Read Access" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Unified Read Access" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Admin Insert" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Admin Update" ON public.${t};\n`;
    new1 += `DROP POLICY IF EXISTS "Admin Delete" ON public.${t};\n`;
});

if (content.includes(target1)) {
    content = content.replace(target1, new1);
    console.log("Patched target1");
}

const target2 = `DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT unnest(ARRAY['config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores', 'dim_produtos'])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Unified Read Access" ON public.%I FOR SELECT USING (public.is_admin() OR public.is_approved())', t);

        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Insert" ON public.%I FOR INSERT WITH CHECK (public.is_admin())', t);

        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Update" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin())', t);

        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Delete" ON public.%I FOR DELETE USING (public.is_admin())', t);
    END LOOP;
END $$;`;

let new2 = ``;
const tables2 = ['config_city_branches', 'dim_supervisores', 'dim_vendedores', 'dim_fornecedores', 'dim_produtos'];
tables2.forEach(t => {
    new2 += `DROP POLICY IF EXISTS "Unified Read Access" ON public.${t};\n`;
    new2 += `CREATE POLICY "Unified Read Access" ON public.${t} FOR SELECT USING (public.is_admin() OR public.is_approved());\n`;
    new2 += `DROP POLICY IF EXISTS "Admin Insert" ON public.${t};\n`;
    new2 += `CREATE POLICY "Admin Insert" ON public.${t} FOR INSERT WITH CHECK (public.is_admin());\n`;
    new2 += `DROP POLICY IF EXISTS "Admin Update" ON public.${t};\n`;
    new2 += `CREATE POLICY "Admin Update" ON public.${t} FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());\n`;
    new2 += `DROP POLICY IF EXISTS "Admin Delete" ON public.${t};\n`;
    new2 += `CREATE POLICY "Admin Delete" ON public.${t} FOR DELETE USING (public.is_admin());\n`;
});

if (content.includes(target2)) {
    content = content.replace(target2, new2);
    console.log("Patched target2");
}


const target3 = `DO $$
DECLARE t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('data_detailed', 'data_history', 'data_clients', 'data_summary', 'data_summary_frequency', 'cache_filters', 'data_innovations', 'data_nota_perfeita', 'relacao_rota_involves')
    LOOP
        -- Read: Approved Users
        EXECUTE format('DROP POLICY IF EXISTS "Unified Read Access" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Unified Read Access" ON public.%I FOR SELECT USING (public.is_approved());', t);

        -- Write: Admins Only
        EXECUTE format('DROP POLICY IF EXISTS "Admin Insert" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Insert" ON public.%I FOR INSERT WITH CHECK (public.is_admin());', t);

        EXECUTE format('DROP POLICY IF EXISTS "Admin Update" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Update" ON public.%I FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());', t);

        EXECUTE format('DROP POLICY IF EXISTS "Admin Delete" ON public.%I', t);
        EXECUTE format('CREATE POLICY "Admin Delete" ON public.%I FOR DELETE USING (public.is_admin());', t);
    END LOOP;
END $$;`;

let new3 = ``;
const tables3 = ['data_detailed', 'data_history', 'data_clients', 'data_summary', 'data_summary_frequency', 'cache_filters', 'data_innovations', 'data_nota_perfeita', 'relacao_rota_involves'];
tables3.forEach(t => {
    new3 += `DROP POLICY IF EXISTS "Unified Read Access" ON public.${t};\n`;
    new3 += `CREATE POLICY "Unified Read Access" ON public.${t} FOR SELECT USING (public.is_approved());\n`;
    new3 += `DROP POLICY IF EXISTS "Admin Insert" ON public.${t};\n`;
    new3 += `CREATE POLICY "Admin Insert" ON public.${t} FOR INSERT WITH CHECK (public.is_admin());\n`;
    new3 += `DROP POLICY IF EXISTS "Admin Update" ON public.${t};\n`;
    new3 += `CREATE POLICY "Admin Update" ON public.${t} FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());\n`;
    new3 += `DROP POLICY IF EXISTS "Admin Delete" ON public.${t};\n`;
    new3 += `CREATE POLICY "Admin Delete" ON public.${t} FOR DELETE USING (public.is_admin());\n`;
});

if (content.includes(target3)) {
    content = content.replace(target3, new3);
    console.log("Patched target3");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
