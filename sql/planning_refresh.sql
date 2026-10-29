-- Apply after planning.sql. Calculations and Farol portfolio refresh are independent.
BEGIN;
CREATE TABLE IF NOT EXISTS private.planning_farol_source (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),payload jsonb NOT NULL,synced_at timestamptz NOT NULL
);
ALTER TABLE private.planning_farol_source ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.planning_farol_source FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS public.planning_refresh_state (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),requested_seq bigint NOT NULL DEFAULT 0,
 processed_seq bigint NOT NULL DEFAULT 0,requested_at timestamptz,finished_at timestamptz,last_error text
);
ALTER TABLE public.planning_refresh_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.planning_refresh_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.planning_refresh_state TO authenticated;
DROP POLICY IF EXISTS planning_refresh_state_read ON public.planning_refresh_state;
CREATE POLICY planning_refresh_state_read ON public.planning_refresh_state FOR SELECT TO authenticated USING ((SELECT public.is_approved()));

-- Keep the same validated calculations, but permit reuse of the last valid Farol snapshot.
DO $install$
DECLARE definition text;old_block text;new_block text;
BEGIN
 definition:=pg_get_functiondef('private.planning_sync()'::regprocedure);
 IF position('private.planning_rebuild' in definition)>0 THEN RETURN; END IF;
 definition:=replace(definition,'private.planning_sync()','private.planning_rebuild(p_refresh_farol boolean)');
 definition:=replace(definition,'old_timeout text; n integer;','old_timeout text; n integer; roster_at timestamptz;');
 old_block:=$old$ SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','20000');
 c:=private.planning_csv_fetch('376419352',ARRAY[1,2,3,5,6,10,16,17,19],2);
 routes:=private.planning_csv_fetch('415990480',ARRAY[1,2,3,10,13],0);
 cal:=private.planning_csv_fetch('988715689',ARRAY[1,2,3],1,true);$old$;
 new_block:=$new$ IF p_refresh_farol THEN
  SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
  PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','20000');
  c:=private.planning_csv_fetch('376419352',ARRAY[1,2,3,5,6,10,16,17,19],2);
  routes:=private.planning_csv_fetch('415990480',ARRAY[1,2,3,10,13],0);
  cal:=private.planning_csv_fetch('988715689',ARRAY[1,2,3],1,true);
  roster_at:=clock_timestamp();
 ELSE
  SELECT payload->'clients',payload->'routes',payload->'calendar',synced_at INTO c,routes,cal,roster_at
  FROM private.planning_farol_source WHERE id=true;
  IF c IS NULL THEN RAISE EXCEPTION 'Carteira do Farol ainda não sincronizada'; END IF;
 END IF;$new$;
 IF position(old_block in definition)=0 THEN RAISE EXCEPTION 'Unexpected planning definition: no changes applied'; END IF;
 definition:=replace(definition,old_block,new_block);
 definition:=replace(definition,' GET DIAGNOSTICS n=ROW_COUNT;',$new$ GET DIAGNOSTICS n=ROW_COUNT;
 IF p_refresh_farol THEN
  INSERT INTO private.planning_farol_source(id,payload,synced_at)
  VALUES(true,jsonb_build_object('clients',c,'routes',routes,'calendar',cal),roster_at)
  ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,synced_at=excluded.synced_at;
 END IF;$new$);
 definition:=replace(definition,$old$'sourceSheetId','1YAAb2oJNltN1AvhHeCsp0jEkbGr8lvjSqq5GAkJLJyg'$old$,
 $new$'rosterSyncedAt',roster_at,'salesUpdatedAt',clock_timestamp(),'sourceSheetId','1YAAb2oJNltN1AvhHeCsp0jEkbGr8lvjSqq5GAkJLJyg'$new$);
 definition:=replace(definition,$old$PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));$old$,
 $new$IF p_refresh_farol THEN PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000')); END IF;$new$);
 EXECUTE definition;
END;$install$;
REVOKE ALL ON FUNCTION private.planning_rebuild(boolean) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.planning_sync()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT private.planning_rebuild(true);
$$;
REVOKE ALL ON FUNCTION private.planning_sync() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.planning_after_dashboard_refresh()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.status<>'succeeded' THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' THEN IF OLD.status='succeeded' THEN RETURN NEW; END IF; END IF;
 INSERT INTO public.planning_refresh_state(id,requested_seq,requested_at)
 VALUES(true,1,clock_timestamp()) ON CONFLICT(id) DO UPDATE
 SET requested_seq=public.planning_refresh_state.requested_seq+1,requested_at=excluded.requested_at,last_error=null;
 RETURN NEW;
END;$$;
REVOKE ALL ON FUNCTION private.planning_after_dashboard_refresh() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS planning_after_dashboard_refresh ON private.dashboard_goal_refresh_runs;
CREATE TRIGGER planning_after_dashboard_refresh AFTER INSERT OR UPDATE OF status ON private.dashboard_goal_refresh_runs
FOR EACH ROW EXECUTE FUNCTION private.planning_after_dashboard_refresh();

CREATE OR REPLACE FUNCTION private.planning_refresh_pending()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE requested bigint;processed bigint;result jsonb;
BEGIN
 IF NOT pg_try_advisory_xact_lock(17890101,415990480) THEN RETURN '{"status":"busy"}'::jsonb; END IF;
 IF EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_runs WHERE status IN('queued','processing')) THEN RETURN '{"status":"waiting_for_dashboard"}'::jsonb; END IF;
 SELECT requested_seq,processed_seq INTO requested,processed FROM public.planning_refresh_state WHERE id=true;
 IF requested IS NULL OR requested<=processed THEN RETURN '{"status":"idle"}'::jsonb; END IF;
 result:=private.planning_rebuild(false);
 IF result->>'status'='synced' THEN
  UPDATE public.planning_refresh_state SET processed_seq=greatest(processed_seq,requested),finished_at=clock_timestamp(),last_error=null WHERE id=true;
 ELSE
  UPDATE public.planning_refresh_state SET last_error=coalesce(result->>'message','Falha ao recalcular planejamento') WHERE id=true;
 END IF;
 RETURN result;
END;$$;
REVOKE ALL ON FUNCTION private.planning_refresh_pending() FROM PUBLIC,anon,authenticated;

DO $readers$
DECLARE signature text;definition text;
BEGIN
 FOREACH signature IN ARRAY ARRAY['public.get_planning_v1(text,text,text,text,integer,integer)','public.get_planning_client_v1(text,uuid)'] LOOP
  definition:=pg_get_functiondef(signature::regprocedure);
  IF position('salesPending' in definition)=0 THEN
   definition:=replace(definition,$old$'syncedAt',snapshot.synced_at$old$,$new$'syncedAt',snapshot.synced_at,'salesPending',coalesce((SELECT requested_seq>processed_seq FROM public.planning_refresh_state WHERE id=true),false)$new$);
   definition:=replace(definition,$old$'syncedAt',s.synced_at$old$,$new$'syncedAt',s.synced_at,'salesPending',coalesce((SELECT requested_seq>processed_seq FROM public.planning_refresh_state WHERE id=true),false)$new$);
   EXECUTE definition;
  END IF;
 END LOOP;
END;$readers$;
COMMIT;
SELECT cron.schedule('refresh-planning-after-dashboard','* * * * *','select private.planning_refresh_pending();');
