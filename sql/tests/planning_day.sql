BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='3s';
DO $$
DECLARE mode text;target text;d jsonb;n integer;amount numeric;
BEGIN
 FOREACH mode IN ARRAY ARRAY['today','yesterday'] LOOP
  target:=to_char((now() AT TIME ZONE 'America/Bahia')::date-CASE WHEN mode='yesterday' THEN 1 ELSE 0 END,'YYYY-MM-DD');
  d:=public.get_planning_day_v1(mode);
  SELECT count(*),coalesce(sum((summary->>'currentValue')::numeric),0) INTO n,amount FROM public.planning_clients WHERE summary->'visitDates' ? target;
  IF d->>'planningDate'<>target OR (d->>'total')::integer<>n OR (d->'kpis'->>'currentValue')::numeric<>amount THEN RAISE EXCEPTION 'Daily scope or totals disagree'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'rows')j WHERE NOT(j->'visitDates' ? target)) THEN RAISE EXCEPTION 'Wrong day client'; END IF;
 END LOOP;
 BEGIN PERFORM public.get_planning_day_v1('tomorrow');RAISE EXCEPTION 'Unexpected date accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 IF has_function_privilege('anon','public.get_planning_day_v1(text,text,text,text,integer,integer)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous access exposed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.planning_snapshot WHERE id=true AND meta->'routeDates' ? to_char(date_trunc('month',now() AT TIME ZONE 'America/Bahia')::date-1,'YYYY-MM-DD')) THEN RAISE EXCEPTION 'Previous month boundary not cached'; END IF;
END;$$;
SELECT jsonb_build_object('day',j->'planningDate','clients',j->'total') verified FROM(SELECT public.get_planning_day_v1('yesterday')j)t;
ROLLBACK;
