BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='3s';
DO $$
DECLARE today text:=to_char(now() AT TIME ZONE 'America/Bahia','YYYY-MM-DD');d jsonb;n integer;value numeric;r record;
BEGIN
 d:=public.get_planning_today_v1();
 SELECT count(*),coalesce(sum((summary->>'currentValue')::numeric),0) INTO n,value FROM public.planning_clients WHERE summary->'visitDates' ? today;
 IF d->>'planningDate'<>today OR (d->>'total')::integer<>n OR (d->'kpis'->>'currentValue')::numeric<>value THEN RAISE EXCEPTION 'Today portfolio or KPIs do not match calendar'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'rows')j WHERE NOT(j->'visitDates' ? today)) THEN RAISE EXCEPTION 'Another day leaked into today'; END IF;
 FOR r IN SELECT DISTINCT supervisor_code,seller_code FROM public.planning_clients LOOP
  d:=public.get_planning_today_v1(r.supervisor_code,r.seller_code);
  SELECT count(*) INTO n FROM public.planning_clients WHERE supervisor_code=r.supervisor_code AND seller_code=r.seller_code AND summary->'visitDates' ? today;
  IF (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Supervisor/seller escaped daily scope'; END IF;
 END LOOP;
 IF has_function_privilege('anon','public.get_planning_today_v1(text,text,text,integer,integer)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous access exposed'; END IF;
END;$$;
SELECT jsonb_build_object('day',j->'planningDate','clientsToday',j->'total','valueToday',j->'kpis'->'currentValue') verified FROM(SELECT public.get_planning_today_v1()j)t;
ROLLBACK;
