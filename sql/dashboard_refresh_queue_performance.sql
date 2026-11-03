-- Remove minute-long idle gaps; keep one cron worker and each task's own transaction.
-- Complete newer months first within the oldest run; calculations stay unchanged.
CREATE OR REPLACE FUNCTION private.dashboard_goal_refresh_process_next()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_task private.dashboard_goal_refresh_tasks%ROWTYPE; v_token uuid; v_run uuid;
BEGIN
    FOR v_run IN
        UPDATE private.dashboard_goal_refresh_tasks
           SET status=CASE WHEN attempts>=3 THEN 'failed' ELSE 'queued' END,
               error_message=coalesce(error_message,'O prazo da tarefa expirou; foi liberada para retomada.'),
               lease_token=NULL,lease_until=NULL,updated_at=clock_timestamp()
         WHERE status='processing' AND lease_until<clock_timestamp()
         RETURNING run_id
    LOOP
        PERFORM private.dashboard_goal_refresh_sync_run(v_run);
    END LOOP;

    -- Goal shares use the prior three summaries. Repair any goal completed
    -- before its run finished rebuilding summaries, then preserve this dependency.
    FOR v_run IN
        UPDATE private.dashboard_goal_refresh_tasks g
           SET status='queued',attempts=0,started_at=NULL,completed_at=NULL,
               lease_token=NULL,lease_until=NULL,error_message=NULL,updated_at=clock_timestamp()
         WHERE g.task_type='goal_attribution' AND g.status='succeeded'
           AND EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_tasks s
                      WHERE s.run_id=g.run_id AND s.task_type='summary' AND s.completed_at>g.completed_at)
           AND NOT EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_tasks s
                          WHERE s.run_id=g.run_id AND s.task_type='summary' AND s.status IN('queued','processing'))
         RETURNING g.run_id
    LOOP
        PERFORM private.dashboard_goal_refresh_sync_run(v_run);
    END LOOP;

    SELECT t.* INTO v_task FROM private.dashboard_goal_refresh_tasks t
     JOIN private.dashboard_goal_refresh_runs r ON r.id=t.run_id
     WHERE t.status='queued'
     ORDER BY r.created_at,r.id,CASE t.task_type WHEN 'summary' THEN 0 ELSE 1 END,
              t.ano DESC,t.mes DESC,t.created_at,t.id
     FOR UPDATE OF t SKIP LOCKED LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;
    v_token:=gen_random_uuid();
    UPDATE private.dashboard_goal_refresh_tasks SET status='processing',attempts=attempts+1,
        lease_token=v_token,lease_until=clock_timestamp()+interval '20 minutes',
        started_at=coalesce(started_at,clock_timestamp()),updated_at=clock_timestamp(),error_message=NULL
     WHERE id=v_task.id RETURNING * INTO v_task;
    PERFORM private.dashboard_goal_refresh_sync_run(v_task.run_id);
    BEGIN
        PERFORM pg_advisory_xact_lock(20261019,v_task.ano*100+v_task.mes);
        PERFORM private.dashboard_goal_refresh_apply(v_task.task_type,v_task.ano,v_task.mes);
        UPDATE private.dashboard_goal_refresh_tasks SET status='succeeded',completed_at=clock_timestamp(),
            updated_at=clock_timestamp(),lease_token=NULL,lease_until=NULL,error_message=NULL WHERE id=v_task.id;
    EXCEPTION WHEN OTHERS THEN
        UPDATE private.dashboard_goal_refresh_tasks SET
            status=CASE WHEN attempts>=3 THEN 'failed' ELSE 'queued' END,
            error_message=left(SQLSTATE||': '||SQLERRM,1000),updated_at=clock_timestamp(),lease_token=NULL,lease_until=NULL
         WHERE id=v_task.id;
    END;
    PERFORM private.dashboard_goal_refresh_sync_run(v_task.run_id);
END;
$function$;
REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_process_next() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.dashboard_goal_refresh_process_next() TO postgres, supabase_admin;

DO $$DECLARE worker_id bigint;BEGIN
 SELECT jobid INTO STRICT worker_id FROM cron.job WHERE jobname='dashboard-goal-refresh-worker';
 PERFORM cron.alter_job(worker_id,schedule:='5 seconds');
END;$$;
