BEGIN;
DO $$
DECLARE d jsonb;
BEGIN
 d:=private.commercial_health_mix_document('["2026-05","2026-06","2026-07","2026-08","2026-09"]','[true,true,true,true,true]',
 '[{"code":"1","name":"A","months":[true,true,false,false,true]},{"code":"2","name":"B","months":[true,false,false,false,true]}]');
 IF d->'monthlyCounts'<>'[2,1,0,0,2]' OR (d->>'historicalAverage')::numeric<>0.75 OR (d->>'previousAverage')::numeric<>2 THEN RAISE EXCEPTION 'Wrong monthly distinct SKU average'; END IF;
 d:=private.commercial_health_mix_document(d->'periods','[true,false,true,true,true]',d->'skus');
 IF d->'historicalAverage'<>'null' OR d->'monthlyCounts'->1<>'null' THEN RAISE EXCEPTION 'Missing source was treated as zero'; END IF;
 IF has_function_privilege('anon','public.get_commercial_health_mix_v1(text,uuid)','EXECUTE') OR has_table_privilege('authenticated','public.commercial_health_mix_cache','UPDATE') OR has_function_privilege('authenticated','private.commercial_health_mix_refresh(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Unexpected mix privileges'; END IF;
 IF EXISTS(SELECT 1 FROM public.commercial_health_mix_cache c CROSS JOIN public.commercial_health_sync s WHERE s.id=true AND c.version::text<>s.payload->>'mixVersion') THEN RAISE EXCEPTION 'Mix versions differ'; END IF;
 IF (SELECT count(*) FROM public.commercial_health_mix_cache)<>(SELECT jsonb_array_length(payload->'rows') FROM public.commercial_health_sync WHERE id=true) THEN RAISE EXCEPTION 'Client coverage mismatch'; END IF;
END;$$;
DO $$
DECLARE r jsonb; result jsonb;
BEGIN
 r:='{"status":"CRÍTICO","mixHistorical":20,"mixPrevious":50}'::jsonb;
 result:=private.commercial_health_mix_classify(r);
 IF result->>'status'<>'ANALISAR' OR result->>'sourceStatus'<>'CRÍTICO' OR result->>'mixReclassified'<>'true' THEN RAISE EXCEPTION 'Exact 2.5x threshold failed'; END IF;
 IF private.commercial_health_mix_classify(result) IS DISTINCT FROM result THEN RAISE EXCEPTION 'Classification is not idempotent'; END IF;
 result:=private.commercial_health_mix_classify(jsonb_set(result,'{mixPrevious}','49'));
 IF result->>'status'<>'CRÍTICO' OR result->>'mixReclassified'<>'false' THEN RAISE EXCEPTION 'Original classification cannot be restored'; END IF;
 IF private.commercial_health_mix_classify(r||'{"mixPrevious":49.99}')->>'status'<>'CRÍTICO' THEN RAISE EXCEPTION 'Below-threshold downgrade'; END IF;
 IF private.commercial_health_mix_classify(r||'{"mixHistorical":0}')->>'status'<>'CRÍTICO' THEN RAISE EXCEPTION 'Zero baseline downgrade'; END IF;
 IF private.commercial_health_mix_classify(r||'{"mixHistorical":null}')->>'status'<>'CRÍTICO' THEN RAISE EXCEPTION 'Missing baseline downgrade'; END IF;
 IF private.commercial_health_mix_classify(r||'{"status":"SEM ALERTA"}')->>'status'<>'SEM ALERTA' THEN RAISE EXCEPTION 'Noncritical status changed'; END IF;
 IF has_function_privilege('authenticated','private.commercial_health_mix_classify(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Private classifier exposed'; END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' AND role='user' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='1s';
DO $$
DECLARE s jsonb; d jsonb; c jsonb;
BEGIN
 s:=public.get_commercial_health_v1();c:=s->'rows'->0;
 d:=public.get_commercial_health_mix_v1(c->>'code',(s->>'mixVersion')::uuid);
 IF d->'historicalAverage' IS DISTINCT FROM c->'mixHistorical' OR d->'previousAverage' IS DISTINCT FROM c->'mixPrevious' THEN RAISE EXCEPTION 'Detail and table disagree'; END IF;
 BEGIN PERFORM public.get_commercial_health_mix_v1(c->>'code','00000000-0000-0000-0000-000000000000');RAISE EXCEPTION 'Stale version accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
END;$$;
ROLLBACK;
