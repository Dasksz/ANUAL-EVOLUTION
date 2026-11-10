BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE team record;st text;d jsonb;n integer;target text:=to_char((now() AT TIME ZONE 'America/Bahia')::date+1,'YYYY-MM-DD');
BEGIN
 FOR team IN SELECT DISTINCT supervisor_code,seller_code FROM public.planning_clients LOOP
  FOREACH st IN ARRAY ARRAY['all','no-sale','ideal','purchased'] LOOP
   d:=public.get_planning_filtered_v1('tomorrow',team.supervisor_code,team.seller_code,'',0,24,st);
   SELECT count(*) INTO n FROM public.planning_clients WHERE supervisor_code=team.supervisor_code AND seller_code=team.seller_code AND summary->'visitDates' ? target
   AND CASE st WHEN 'no-sale' THEN (summary->>'currentMix')::integer=0 WHEN 'ideal' THEN coalesce((summary->'mixIdeal'->>'achieved')::boolean,false) WHEN 'purchased' THEN (summary->>'currentMix')::integer>0 ELSE true END;
   IF (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Tomorrow filtered count differs';END IF;
  END LOOP;
 END LOOP;
END $test$;
SELECT jsonb_build_object('date',d->'planningDate','clients',d->'total','kpis',d->'kpis') verified FROM(SELECT public.get_planning_filtered_v1('tomorrow')d)t;
ROLLBACK;
