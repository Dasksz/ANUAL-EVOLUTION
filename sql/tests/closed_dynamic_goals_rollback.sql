-- Read-only regression: run after deploying the annual chart function.
-- Every closed dynamic month follows actuals; fixed goals remain independent.
BEGIN;
DO $test$
DECLARE result jsonb; month_row jsonb; metric text; supervisor text;
BEGIN
FOREACH supervisor IN ARRAY ARRAY[NULL::text, '18', '21'] LOOP
result := public.get_metas_anuais_chart(2026,supervisor,NULL::text,12,'Todos'::text,'Todas'::text,'Todos'::text);
FOR month_row IN SELECT value FROM jsonb_array_elements(result->'chart_data') LOOP
FOREACH metric IN ARRAY ARRAY['fat','vol','pos','salty','foods'] LOOP
IF (month_row->>'mes')::integer <= (result->>'mes_fechado')::integer THEN
IF month_row->('kpi_meta_estimada_'||metric) IS DISTINCT FROM month_row->('kpi_realizado_atual_'||metric) THEN
RAISE EXCEPTION 'Closed dynamic goal differs from actual: supervisor %, month %, metric %', supervisor, month_row->>'mes', metric;
END IF;
ELSIF month_row->('kpi_meta_fixa_'||metric) IS DISTINCT FROM 'null'::jsonb THEN
RAISE EXCEPTION 'Fixed goal exposed before month closes: month %, metric %', month_row->>'mes', metric;
END IF;
END LOOP;
END LOOP;
END LOOP;
END $test$;
SELECT 'PASS: closed dynamic goals and fixed future gaps, global and Romulo' AS verification;
ROLLBACK;
