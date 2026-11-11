-- Hide the historical bucket from the supervisor selector, not from sales.
DO $migration$
DECLARE
    fn regprocedure := 'public.get_dashboard_filters(text[],text[],text[],text[],text[],text,text,text[],text[],text[])'::regprocedure;
    current_def text := pg_get_functiondef(fn);
    previous_clause text := $clause$AND superv IS NOT NULL AND UPPER(superv) NOT LIKE ''INATIVOS%'' ORDER BY superv$clause$;
    new_clause text := $clause$AND superv IS NOT NULL AND UPPER(superv) NOT LIKE ''INATIVOS%'' AND UPPER(BTRIM(superv)) <> ''SEM SUPERVISOR ATUAL'' ORDER BY superv$clause$;
BEGIN
    IF strpos(current_def, new_clause) > 0 THEN RETURN; END IF;
    IF strpos(current_def, previous_clause) = 0 THEN
        RAISE EXCEPTION 'Supervisor filter definition changed; review before replacing';
    END IF;
    EXECUTE replace(current_def, previous_clause, new_clause);
END
$migration$;
