BEGIN;
DO $$
DECLARE t jsonb; p jsonb; bad jsonb; before_snapshot jsonb;
BEGIN
 t:=jsonb_build_object('cols',(SELECT jsonb_agg(jsonb_build_object('label',v)) FROM unnest(ARRAY['CODCLI','CLIENTE','MAIO','JUNHO','JULHO','AGOSTO','MÉDIAHIST','MEDIANAHIST','SETEMBRO','VARIAÇÃO%','OUTUBRO','MESESPOSIT','RESULTADO','EXEDENTE/MED'])v),
 'rows',jsonb_build_array(jsonb_build_object('c',(SELECT jsonb_agg(jsonb_build_object('v',value)) FROM jsonb_array_elements('[12320,"Cliente teste",10,20,10,0,10,10,100,9,0,3,"CRÍTICO",90]')))));
 t:=jsonb_set(t,'{rows}',(t->'rows')||(t->'rows'));
 p:=private.commercial_health_parse(t);
 IF jsonb_array_length(p->'rows')<>1 OR p->>'duplicatesMerged'<>'1' OR (p->'rows'->0->>'previous')::numeric<>100 THEN RAISE EXCEPTION 'Duplicate allocation regression'; END IF;
 bad:=jsonb_set(t,'{rows,1,c,8,v}','999');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Conflicting duplicate accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 bad:=jsonb_set(t,'{rows,0,c,12,v}','"OTHER"');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Invalid status accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 bad:=jsonb_set(t,'{rows,0,c,2,v}','null');
 BEGIN PERFORM private.commercial_health_parse(bad);RAISE EXCEPTION 'Missing number accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 IF has_function_privilege('anon','public.get_commercial_health_v1()','EXECUTE') OR has_function_privilege('authenticated','private.sync_commercial_health_from_sheet()','EXECUTE') OR has_table_privilege('authenticated','public.commercial_health_sync','UPDATE') THEN RAISE EXCEPTION 'Unexpected write or anonymous permissions';END IF;
END;$$;
ROLLBACK;
