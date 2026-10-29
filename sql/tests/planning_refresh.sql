-- All changes below roll back, including test sales, run status and the network stub.
BEGIN;
SET LOCAL statement_timeout='30s';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
CREATE OR REPLACE FUNCTION private.planning_csv_fetch(gid text,selected_columns integer[],header_row integer,is_calendar boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Unexpected Sheets request during sales refresh'; END;$$;
DO $$
DECLARE run uuid:=gen_random_uuid();before_requested bigint;after_requested bigint;client_id text;tid tid;oid_value oid;
 old_value numeric;old_average numeric;roster_time timestamptz;roster_hash text;result jsonb;initial_version uuid;d jsonb;
BEGIN
 IF has_function_privilege('authenticated','private.planning_rebuild(boolean)','EXECUTE') OR has_table_privilege('authenticated','public.planning_refresh_state','UPDATE') THEN RAISE EXCEPTION 'Refresh privileges too broad'; END IF;
 SELECT coalesce(requested_seq,0) INTO before_requested FROM public.planning_refresh_state WHERE id=true;before_requested:=coalesce(before_requested,0);
 SELECT synced_at,md5(payload::text) INTO roster_time,roster_hash FROM private.planning_farol_source WHERE id=true;
 SELECT version INTO initial_version FROM public.planning_snapshot WHERE id=true;
 SELECT s.codcli,s.ctid,s.tableoid INTO client_id,tid,oid_value FROM public.data_detailed s JOIN public.planning_clients p ON p.code=s.codcli
 WHERE s.codfor IN('707','708','752','1119') AND s.tipovenda IN('1','9') AND s.vlvenda>0 AND s.qtvenda>0 LIMIT 1;
 SELECT (summary->>'currentValue')::numeric,(summary->>'averageValue')::numeric INTO old_value,old_average FROM public.planning_clients WHERE code=client_id;
 UPDATE public.data_detailed SET vlvenda=vlvenda+12.34 WHERE tableoid=oid_value AND ctid=tid;
 INSERT INTO private.dashboard_goal_refresh_runs(id,status,source) VALUES(run,'queued','planning-regression-test');
 IF private.planning_refresh_pending()->>'status'<>'waiting_for_dashboard' THEN RAISE EXCEPTION 'Read data before dashboard finished'; END IF;
 UPDATE private.dashboard_goal_refresh_runs SET status='succeeded' WHERE id=run;
 SELECT requested_seq INTO after_requested FROM public.planning_refresh_state WHERE id=true;
 IF after_requested<>before_requested+1 THEN RAISE EXCEPTION 'Completion did not queue planning refresh'; END IF;
 UPDATE private.dashboard_goal_refresh_runs SET status='succeeded' WHERE id=run;
 IF (SELECT requested_seq FROM public.planning_refresh_state WHERE id=true)<>after_requested THEN RAISE EXCEPTION 'Repeated success queued twice'; END IF;
 d:=public.get_planning_v1();IF NOT(d->>'salesPending')::boolean THEN RAISE EXCEPTION 'Pending sales flag missing'; END IF;
 result:=private.planning_refresh_pending();
 IF result->>'status'<>'synced' THEN RAISE EXCEPTION 'Sales refresh failed: %',result; END IF;
 IF abs((SELECT (summary->>'currentValue')::numeric FROM public.planning_clients WHERE code=client_id)-old_value-12.34)>0.00001 THEN RAISE EXCEPTION 'New current-month sales not reflected'; END IF;
 IF (SELECT (summary->>'averageValue')::numeric FROM public.planning_clients WHERE code=client_id) IS DISTINCT FROM old_average THEN RAISE EXCEPTION 'Historical average changed during current-month-only update'; END IF;
 IF (SELECT synced_at FROM private.planning_farol_source WHERE id=true)<>roster_time OR (SELECT md5(payload::text) FROM private.planning_farol_source WHERE id=true)<>roster_hash THEN RAISE EXCEPTION 'Sales refresh changed the source portfolio'; END IF;
 IF (SELECT version FROM public.planning_snapshot WHERE id=true)=initial_version THEN RAISE EXCEPTION 'Planning version did not advance'; END IF;
 IF (SELECT meta->>'rosterSyncedAt' FROM public.planning_snapshot WHERE id=true)::timestamptz<>roster_time THEN RAISE EXCEPTION 'Roster timestamp was falsified'; END IF;
 IF (SELECT requested_seq<>processed_seq FROM public.planning_refresh_state WHERE id=true) THEN RAISE EXCEPTION 'Request not acknowledged'; END IF;
 IF (public.get_planning_v1()->>'salesPending')::boolean THEN RAISE EXCEPTION 'Pending status did not clear'; END IF;
 IF private.planning_refresh_pending()->>'status'<>'idle' THEN RAISE EXCEPTION 'Unrequested recalculation'; END IF;
END;$$;
ROLLBACK;

BEGIN;
SET LOCAL statement_timeout='10s';
DO $$
DECLARE old_version uuid;old_hash text;result jsonb;old_processed bigint;
BEGIN
 SELECT version INTO old_version FROM public.planning_snapshot WHERE id=true;
 SELECT md5(string_agg(summary::text||detail::text,'' ORDER BY code)) INTO old_hash FROM public.planning_clients;
 INSERT INTO public.planning_refresh_state(id,requested_seq,requested_at) VALUES(true,1,clock_timestamp())
 ON CONFLICT(id) DO UPDATE SET requested_seq=public.planning_refresh_state.requested_seq+1;
 SELECT processed_seq INTO old_processed FROM public.planning_refresh_state WHERE id=true;
 UPDATE private.planning_farol_source SET payload=jsonb_set(payload,'{clients}','null') WHERE id=true;
 result:=private.planning_refresh_pending();
 IF result->>'status'<>'error' THEN RAISE EXCEPTION 'Bad source was accepted'; END IF;
 IF (SELECT version FROM public.planning_snapshot WHERE id=true)<>old_version OR (SELECT md5(string_agg(summary::text||detail::text,'' ORDER BY code)) FROM public.planning_clients)<>old_hash THEN RAISE EXCEPTION 'Failure replaced the last valid plan'; END IF;
 IF (SELECT processed_seq FROM public.planning_refresh_state WHERE id=true)<>old_processed THEN RAISE EXCEPTION 'Failed refresh was incorrectly acknowledged'; END IF;
END;$$;
ROLLBACK;
