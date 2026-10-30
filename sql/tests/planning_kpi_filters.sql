BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='60s';
DO $$
DECLARE d jsonb;b jsonb;expected integer;n integer;mode text;state text;scope record;search text;
BEGIN
 FOR scope IN SELECT NULL::text supervisor,NULL::text seller UNION SELECT DISTINCT supervisor_code,seller_code FROM public.planning_clients LOOP
 FOREACH mode IN ARRAY ARRAY['today','yesterday','unrouted'] LOOP
 FOREACH search IN ARRAY ARRAY['','mercado'] LOOP
 b:=public.get_planning_day_v1(mode,scope.supervisor,scope.seller,search);
 FOREACH state IN ARRAY ARRAY['all','no-sale','ideal','purchased'] LOOP
 d:=public.get_planning_filtered_v1(mode,scope.supervisor,scope.seller,search,0,24,state);
 SELECT count(*) INTO expected FROM public.planning_clients WHERE version=(b->>'version')::uuid
 AND(scope.supervisor IS NULL OR supervisor_code=scope.supervisor) AND(scope.seller IS NULL OR seller_code=scope.seller)
 AND(CASE WHEN mode='unrouted' THEN jsonb_array_length(summary->'visitDates')=0 ELSE summary->'visitDates' ? (b->>'planningDate') END)
 AND(search='' OR position(lower(search) in lower(summary->>'code'||' '||(summary->>'name')||' '||(summary->>'city')))>0)
 AND(CASE state WHEN 'no-sale' THEN (summary->>'currentMix')::integer=0 WHEN 'ideal' THEN coalesce((summary->'mixIdeal'->>'achieved')::boolean,false) WHEN 'purchased' THEN (summary->>'currentMix')::integer>0 ELSE true END);
 IF (d->>'total')::integer<>expected OR (d->>'scopeTotal')::integer<>(b->>'total')::integer OR d->'kpis'<>b->'kpis' THEN RAISE EXCEPTION 'KPI scope/count mismatch: %, %, %, %',mode,state,scope,search; END IF;
 IF jsonb_array_length(d->'rows')<>least(expected,24) THEN RAISE EXCEPTION 'Pagination count mismatch'; END IF;
 SELECT count(*) INTO n FROM jsonb_array_elements(d->'rows')j WHERE CASE state WHEN 'no-sale' THEN (j->>'currentMix')::integer<>0 WHEN 'ideal' THEN NOT coalesce((j->'mixIdeal'->>'achieved')::boolean,false) WHEN 'purchased' THEN (j->>'currentMix')::integer<=0 ELSE false END;
 IF n<>0 THEN RAISE EXCEPTION 'Wrong client classification'; END IF;
 IF state='all' AND d->'rows'<>b->'rows' THEN RAISE EXCEPTION 'Default order changed'; END IF;
 IF expected>24 THEN
  d:=public.get_planning_filtered_v1(mode,scope.supervisor,scope.seller,search,24,24,state);
  IF jsonb_array_length(d->'rows')<>least(expected-24,24) THEN RAISE EXCEPTION 'Second page mismatch'; END IF;
 END IF;
 END LOOP;END LOOP;END LOOP;END LOOP;
 BEGIN PERFORM public.get_planning_filtered_v1(p_status:='invalid');RAISE EXCEPTION 'Invalid status accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END;$$;
SELECT 'KPI filtering, hierarchy, search, day scopes and pagination verified' as result;
ROLLBACK;
