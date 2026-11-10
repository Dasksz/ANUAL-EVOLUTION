BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE mode text;st text;sup text;sellers text[];d jsonb;target text;n integer;item jsonb;expected jsonb;
BEGIN
 FOREACH mode IN ARRAY ARRAY['today','tomorrow'] LOOP
  FOREACH sup IN ARRAY ARRAY[NULL::text,'12','21'] LOOP
   SELECT array_agg(seller_code) INTO sellers FROM(SELECT DISTINCT seller_code FROM public.planning_clients WHERE sup IS NULL OR supervisor_code=sup ORDER BY 1 LIMIT 2)s;
   FOREACH st IN ARRAY ARRAY['all','no-sale','ideal','purchased'] LOOP
    d:=public.get_planning_portfolio_v1(mode,sup,sellers,'',0,1,st,true);target:=d->>'planningDate';
    SELECT count(*) INTO n FROM public.planning_clients c WHERE summary->'visitDates' ? target AND(sup IS NULL OR supervisor_code=sup) AND seller_code=ANY(sellers)
    AND CASE st WHEN 'no-sale' THEN (summary->>'currentMix')::integer=0 WHEN 'purchased' THEN (summary->>'currentMix')::integer>0 WHEN 'ideal' THEN coalesce((summary->'mixIdeal'->>'achieved')::boolean,false) ELSE true END;
    IF jsonb_array_length(d->'rows')<>n OR (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Export filters or pagination lost'; END IF;
    FOR item IN SELECT value FROM jsonb_array_elements(d->'rows') LOOP
     SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('family',k->>'family','category',k->>'category')),'[]'::jsonb) INTO expected FROM public.planning_clients c,jsonb_array_elements(c.detail->'skus')k WHERE c.code=item->>'code' AND(k->>'current')::boolean AND nullif(k->>'category','') IS NOT NULL;
     IF NOT(expected @> (item->'categoryPresence') AND (item->'categoryPresence') @> expected) THEN RAISE EXCEPTION 'Category checks differ from actual purchases';END IF;
    END LOOP;
   END LOOP;
  END LOOP;
 END LOOP;
 FOREACH mode IN ARRAY ARRAY['yesterday','unrouted'] LOOP
  BEGIN PERFORM public.get_planning_portfolio_v1(p_day=>mode,p_export=>true);RAISE EXCEPTION 'Invalid export day accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 END LOOP;
 IF has_function_privilege('anon','public.get_planning_portfolio_v1(text,text,text[],text,integer,integer,text,boolean)','EXECUTE') THEN RAISE EXCEPTION 'Anonymous export';END IF;
END;$$;
ROLLBACK;
