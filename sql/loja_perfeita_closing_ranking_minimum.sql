-- Require five recorded surveys per researcher (RCA or promoter) in the selected scope.
DO $migration$
DECLARE
 fn regprocedure := 'public.get_loja_perfeita_closing_data(text[],text[],text[],text[],text[],text,integer,integer,text[],text[])'::regprocedure;
 def text := pg_get_functiondef(fn);
BEGIN
 IF strpos(def,'HAVING SUM(recorded_surveys) >= 5') > 0 THEN RETURN; END IF;
 IF md5(def) <> '4df92b15652e23dc27313f06b8fad1d7' THEN RAISE EXCEPTION 'Closing ranking definition changed'; END IF;
 def := replace(def,'SUM(GREATEST(COALESCE(auditorias, 1), 1)) AS audits','SUM(GREATEST(COALESCE(auditorias, 1), 1)) AS audits, SUM(GREATEST(COALESCE(auditorias, 0), 0)) AS recorded_surveys');
 def := replace(def,'FROM researcher_client_avgs GROUP BY researcher','FROM researcher_client_avgs GROUP BY researcher'||chr(10)||'            HAVING SUM(recorded_surveys) >= 5');
 IF strpos(def,'AS recorded_surveys') = 0 OR strpos(def,'HAVING SUM(recorded_surveys) >= 5') = 0 THEN RAISE EXCEPTION 'Ranking patch did not apply'; END IF;
 EXECUTE def;
END
$migration$;
