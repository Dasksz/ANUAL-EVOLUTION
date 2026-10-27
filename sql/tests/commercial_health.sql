BEGIN;
DO $$
DECLARE t jsonb; p jsonb; bad jsonb; before_snapshot jsonb;
BEGIN
 t:=jsonb_build_object('cols',(SELECT jsonb_agg(jsonb_build_object('label',v)) FROM unnest(ARRAY['CODCLI','CLIENTE','MAIO','JUNHO','JULHO','AGOSTO','MÉDIAHIST','MEDIANAHIST','SETEMBRO','VARIAÇÃO%','OUTUBRO','MESESPOSIT','RESULTADO','EXEDENTE/MED'])v),
 'rows',jsonb_build_array(jsonb_build_object('c',(SELECT jsonb_agg(jsonb_build_object('v',value)) FROM jsonb_array_elements('[12320,"Cliente teste",10,20,10,0,10,10,100,9,0,3,"CRÍTICO",90]')))));
 t:=jsonb_set(t,'{rows}',(t->'rows')||(t->'rows'));
 p:=private.commercial_health_parse(t);
 IF jsonb_array_length(p->'rows')<>1 OR p->>'duplicatesMerged'<>'1' OR (p->'rows'->0->>'previous')::numeric<>100 THEN RAISE EXCEPTION 'Duplicate allocation regression'; END IF;
 bad:=jsonb_set(jsonb_set(t,'{rows,0,c,12,v}','"SAUDÁVEL"'),'{rows,1,c,12,v}','"SAUDÁVEL"');
 IF private.commercial_health_parse(bad)->'rows'->0->>'status'<>'SEM ALERTA' THEN RAISE EXCEPTION 'Legacy no-alert label regression'; END IF;
 bad:=jsonb_set(t,'{rows,1,c,8,v}','999');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Conflicting duplicate accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 bad:=jsonb_set(t,'{rows,0,c,12,v}','"OTHER"');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Invalid status accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 bad:=jsonb_set(t,'{rows,0,c,2,v}','null');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Missing number accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 IF has_function_privilege('anon','public.get_commercial_health_v1()','EXECUTE') OR has_function_privilege('authenticated','private.sync_commercial_health_from_sheet()','EXECUTE') OR has_table_privilege('authenticated','public.commercial_health_sync','UPDATE') THEN RAISE EXCEPTION 'Unexpected write or anonymous permissions';END IF;
END;$$;
ROLLBACK;

-- Exercise the real authenticated RLS path within a deadline below PostgREST's 8s.
-- This integration check requires a valid synced snapshot and approved test profiles.
BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' AND role='user' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='1s';
DO $$
DECLARE p jsonb;
BEGIN
 p:=public.get_commercial_health_v1();
 IF jsonb_array_length(p->'rows')<1 OR p->>'syncedAt' IS NULL THEN RAISE EXCEPTION 'Missing snapshot'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p->'rows') r WHERE NOT (r ?& ARRAY['sellerCode','seller','supervisorCode','supervisor'])) THEN RAISE EXCEPTION 'Assignments were not precomputed'; END IF;
 IF has_function_privilege('authenticated','private.commercial_health_enrich(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Private enrichment exposed'; END IF;
END;$$;
ROLLBACK;
BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' AND role='adm' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='1s';
DO $$
DECLARE p jsonb;
BEGIN
 p:=public.get_commercial_health_v1();
 IF jsonb_array_length(p->'rows')<1 OR p->>'syncedAt' IS NULL THEN RAISE EXCEPTION 'Missing snapshot'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p->'rows') r WHERE NOT (r ?& ARRAY['sellerCode','seller','supervisorCode','supervisor'])) THEN RAISE EXCEPTION 'Assignments were not precomputed'; END IF;
 IF has_function_privilege('authenticated','private.commercial_health_enrich(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'Private enrichment exposed'; END IF;
END;$$;
ROLLBACK;
