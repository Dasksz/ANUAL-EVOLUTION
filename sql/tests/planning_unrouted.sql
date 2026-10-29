BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='3s';
DO $$
DECLARE d jsonb;n integer;amount numeric;r record;
BEGIN
 d:=public.get_planning_day_v1('unrouted');
 SELECT count(*),coalesce(sum((summary->>'currentValue')::numeric),0) INTO n,amount FROM public.planning_clients WHERE jsonb_array_length(summary->'visitDates')=0;
 IF (d->>'total')::integer<>n OR (d->'kpis'->>'currentValue')::numeric<>amount THEN RAISE EXCEPTION 'Unrouted count or revenue mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'rows')j WHERE jsonb_array_length(j->'visitDates')>0) THEN RAISE EXCEPTION 'Routed client leaked into unrouted view'; END IF;
 FOR r IN SELECT DISTINCT supervisor_code,seller_code FROM public.planning_clients LOOP
  d:=public.get_planning_day_v1('unrouted',r.supervisor_code,r.seller_code);
  SELECT count(*) INTO n FROM public.planning_clients WHERE supervisor_code=r.supervisor_code AND seller_code=r.seller_code AND jsonb_array_length(summary->'visitDates')=0;
  IF (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Unrouted hierarchy filter failed'; END IF;
 END LOOP;
 IF (public.get_planning_day_v1('today')->>'planningDay')<>'today' OR (public.get_planning_day_v1('yesterday')->>'planningDay')<>'yesterday' THEN RAISE EXCEPTION 'Existing daily modes changed'; END IF;
END;$$;
SELECT jsonb_build_object('mode',j->'planningDay','clients',j->'total') verified FROM(SELECT public.get_planning_day_v1('unrouted')j)t;
ROLLBACK;
