-- Exclude Vanessia (78) and Ubiratan (174) from the closing ranking only.
DO $migration$
DECLARE
    fn regprocedure := 'public.get_loja_perfeita_closing_data(text[],text[],text[],text[],text[],text,integer,integer,text[],text[])'::regprocedure;
    def text := pg_get_functiondef(fn);
    old_clause text := $clause$COALESCE(ltrim(researcher_vendor_code, ''0''), '''') <> ''190''$clause$;
    new_clause text := $clause$COALESCE(ltrim(btrim(researcher_vendor_code), ''0''), '''') NOT IN (''190'', ''78'', ''174'')$clause$;
BEGIN
    IF strpos(def, new_clause) > 0 THEN RETURN; END IF;
    IF strpos(def, old_clause) = 0 OR strpos(def, 'ranking_scope_v1') = 0 THEN
        RAISE EXCEPTION 'Closing ranking definition changed; review the exclusion';
    END IF;
    EXECUTE replace(def, old_clause, new_clause);
END
$migration$;
