const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const target1 = `CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
SET search_path = public
AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND role = 'adm');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;`;

const target2 = `CREATE OR REPLACE FUNCTION public.is_approved() RETURNS boolean
SET search_path = public
AS $$
BEGIN
  IF (select auth.role()) = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = (select auth.uid()) AND status = 'aprovado');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;`;

// A function needs its LANGUAGE declared BEFORE the AS block or AFTER the block, but here it is AFTER which is fine.
// But wait, the error is: syntax error at or near "IF"
// In PostgreSQL, IF requires a boolean expression.
// "(select auth.role()) = 'service_role'" is a subquery. Subqueries in IF conditions might need to be evaluated differently in PL/pgSQL, or maybe it just needs to be properly wrapped or stored in a variable. Or just: IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
// Or wait, auth.role() returns text. So IF auth.role() = 'service_role' THEN ...
// But wait! Is auth.role() an existing function in Supabase? Yes, it is. But wait, why is the subquery "(select auth.role())" failing? Because in PL/pgSQL, you can't just use a SELECT subquery directly inside an IF condition without wrapping it properly or selecting into a variable. Or you can just call the function directly: IF auth.role() = 'service_role' THEN

if (content.includes(target1)) {
    content = content.replace(target1, `CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'adm');
END;
$$;`);
    console.log("Patched is_admin!");
} else {
    console.log("target1 not found");
}

if (content.includes(target2)) {
    content = content.replace(target2, `CREATE OR REPLACE FUNCTION public.is_approved() RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() = 'service_role' THEN RETURN true; END IF;
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND status = 'aprovado');
END;
$$;`);
    console.log("Patched is_approved!");
} else {
    console.log("target2 not found");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
