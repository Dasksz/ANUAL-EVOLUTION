-- Durable background refresh queue for the dashboard's monthly summaries and goal attribution.
-- The uploader commits raw data first, then enqueues one task per affected month.

CREATE TABLE IF NOT EXISTS private.dashboard_goal_refresh_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    requested_by uuid DEFAULT auth.uid(),
    source text NOT NULL DEFAULT 'uploader',
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued','processing','succeeded','failed')),
    task_count integer NOT NULL DEFAULT 0,
    completed_count integer NOT NULL DEFAULT 0,
    failed_count integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    error_summary text
);

CREATE TABLE IF NOT EXISTS private.dashboard_goal_refresh_tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id uuid NOT NULL REFERENCES private.dashboard_goal_refresh_runs(id) ON DELETE CASCADE,
    task_type text NOT NULL CHECK (task_type IN ('summary','goal_attribution')),
    ano integer NOT NULL CHECK (ano BETWEEN 1 AND 9998),
    mes integer NOT NULL CHECK (mes BETWEEN 1 AND 12),
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued','processing','succeeded','failed')),
    attempts integer NOT NULL DEFAULT 0,
    lease_token uuid,
    lease_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    started_at timestamptz,
    completed_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    error_message text,
    UNIQUE (run_id, task_type, ano, mes)
);

CREATE INDEX IF NOT EXISTS dashboard_goal_refresh_tasks_queue_idx
    ON private.dashboard_goal_refresh_tasks (created_at, ano, mes)
    WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS dashboard_goal_refresh_tasks_run_idx
    ON private.dashboard_goal_refresh_tasks (run_id, status, created_at);
CREATE INDEX IF NOT EXISTS dashboard_goal_refresh_tasks_lease_idx
    ON private.dashboard_goal_refresh_tasks (lease_until)
    WHERE status = 'processing';

ALTER TABLE private.dashboard_goal_refresh_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.dashboard_goal_refresh_tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.dashboard_goal_refresh_runs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.dashboard_goal_refresh_tasks FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.dashboard_goal_refresh_sync_run(p_run_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_total integer; v_done integer; v_failed integer; v_status text;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE status='succeeded'), count(*) FILTER (WHERE status='failed')
      INTO v_total,v_done,v_failed
      FROM private.dashboard_goal_refresh_tasks WHERE run_id=p_run_id;
    v_status := CASE
      WHEN v_total=0 OR v_done=v_total THEN 'succeeded'
      WHEN v_failed>0 AND NOT EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_tasks WHERE run_id=p_run_id AND status IN ('queued','processing')) THEN 'failed'
      WHEN EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_tasks WHERE run_id=p_run_id AND status='processing') THEN 'processing'
      ELSE 'queued' END;
    UPDATE private.dashboard_goal_refresh_runs
       SET task_count=v_total, completed_count=v_done, failed_count=v_failed,
           status=v_status, updated_at=clock_timestamp(),
           completed_at=CASE WHEN v_status IN ('succeeded','failed') THEN coalesce(completed_at,clock_timestamp()) ELSE NULL END,
           error_summary=(SELECT left(string_agg(DISTINCT error_message,'; '),1000)
                            FROM private.dashboard_goal_refresh_tasks
                           WHERE run_id=p_run_id AND status='failed' AND error_message IS NOT NULL)
     WHERE id=p_run_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_enqueue_dashboard_goal_refresh(p_periods jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_run_id uuid; v_period jsonb; v_year integer; v_month integer; v_offset integer;
        v_target_idx integer; v_task_count integer;
BEGIN
    PERFORM private.evolution_assert_admin();
    IF jsonb_typeof(p_periods) <> 'array' OR jsonb_array_length(p_periods)>240 THEN
        RAISE EXCEPTION 'Períodos inválidos para atualização de metas.' USING ERRCODE='22023';
    END IF;

    INSERT INTO private.dashboard_goal_refresh_runs(source,requested_by)
    VALUES ('uploader',auth.uid()) RETURNING id INTO v_run_id;

    FOR v_period IN SELECT value FROM jsonb_array_elements(p_periods) LOOP
        IF coalesce(v_period->>'year','') !~ '^\d{1,4}$' OR coalesce(v_period->>'month','') !~ '^\d{1,2}$' THEN
            RAISE EXCEPTION 'Período inválido para atualização de metas.' USING ERRCODE='22023';
        END IF;
        v_year := (v_period->>'year')::integer;
        v_month := (v_period->>'month')::integer;
        IF v_year NOT BETWEEN 1 AND 9998 OR v_month NOT BETWEEN 1 AND 12 THEN
            RAISE EXCEPTION 'Período inválido para atualização de metas.' USING ERRCODE='22023';
        END IF;
        INSERT INTO private.dashboard_goal_refresh_tasks(run_id,task_type,ano,mes)
        VALUES (v_run_id,'summary',v_year,v_month)
        ON CONFLICT (run_id,task_type,ano,mes) DO NOTHING;

        -- Historical sales in month S affect rolling three-month attribution for S+1..S+3.
        FOR v_offset IN 1..3 LOOP
            v_target_idx := v_year*12 + v_month - 1 + v_offset;
            IF EXISTS (
                SELECT 1 FROM private.evolution_official_targets t
                 WHERE t.ano = ((v_target_idx-1)/12)::integer
                   AND t.mes = ((v_target_idx-1)%12)+1
            ) THEN
                INSERT INTO private.dashboard_goal_refresh_tasks(run_id,task_type,ano,mes)
                VALUES (v_run_id,'goal_attribution',((v_target_idx-1)/12)::integer,((v_target_idx-1)%12)+1)
                ON CONFLICT (run_id,task_type,ano,mes) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;

    SELECT count(*) INTO v_task_count FROM private.dashboard_goal_refresh_tasks WHERE run_id=v_run_id;
    PERFORM private.dashboard_goal_refresh_sync_run(v_run_id);
    RETURN jsonb_build_object('job_id',v_run_id,'status',CASE WHEN v_task_count=0 THEN 'succeeded' ELSE 'queued' END,'task_count',v_task_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_dashboard_goal_refresh_claim(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_task private.dashboard_goal_refresh_tasks%ROWTYPE; v_token uuid;
BEGIN
    PERFORM private.evolution_assert_admin();
    UPDATE private.dashboard_goal_refresh_tasks
       SET status=CASE WHEN attempts>=3 THEN 'failed' ELSE 'queued' END,
           lease_token=NULL,lease_until=NULL,updated_at=clock_timestamp(),
           error_message=coalesce(error_message,'O processamento anterior expirou; tarefa será retomada.')
     WHERE run_id=p_run_id AND status='processing' AND lease_until<clock_timestamp();

    SELECT * INTO v_task
      FROM private.dashboard_goal_refresh_tasks
     WHERE run_id=p_run_id AND status='queued'
     ORDER BY CASE task_type WHEN 'summary' THEN 0 ELSE 1 END,ano,mes,created_at
     FOR UPDATE SKIP LOCKED LIMIT 1;
    IF NOT FOUND THEN
        PERFORM private.dashboard_goal_refresh_sync_run(p_run_id);
        RETURN NULL;
    END IF;
    v_token := gen_random_uuid();
    UPDATE private.dashboard_goal_refresh_tasks
       SET status='processing', attempts=attempts+1, lease_token=v_token,
           lease_until=clock_timestamp()+interval '20 minutes',
           started_at=coalesce(started_at,clock_timestamp()),updated_at=clock_timestamp(),error_message=NULL
     WHERE id=v_task.id;
    PERFORM private.dashboard_goal_refresh_sync_run(p_run_id);
    RETURN jsonb_build_object('task_id',v_task.id,'lease_token',v_token,'task_type',v_task.task_type,'year',v_task.ano,'month',v_task.mes,'attempt',v_task.attempts+1);
END;
$function$;

CREATE OR REPLACE FUNCTION private.dashboard_goal_refresh_apply(p_task_type text,p_year integer,p_month integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    IF p_task_type='summary' THEN
        PERFORM public.refresh_summary_month(p_year,p_month);
        PERFORM public.refresh_cache_filters(p_year,p_month);
    ELSIF p_task_type='goal_attribution' THEN
        PERFORM private.evolution_sync_meta_period(p_year,p_month,true);
    ELSE
        RAISE EXCEPTION 'Tipo de tarefa inválido.' USING ERRCODE='22023';
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_dashboard_goal_refresh_process(p_task_id uuid,p_lease_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_task private.dashboard_goal_refresh_tasks%ROWTYPE;
BEGIN
    PERFORM private.evolution_assert_admin();
    SELECT * INTO v_task FROM private.dashboard_goal_refresh_tasks
     WHERE id=p_task_id AND status='processing' AND lease_token=p_lease_token
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'A tarefa não está mais reservada por este processamento.' USING ERRCODE='40001'; END IF;
    PERFORM pg_advisory_xact_lock(20261019, v_task.ano*100+v_task.mes);
    PERFORM private.dashboard_goal_refresh_apply(v_task.task_type,v_task.ano,v_task.mes);
    UPDATE private.dashboard_goal_refresh_tasks
       SET status='succeeded',completed_at=clock_timestamp(),updated_at=clock_timestamp(),
           lease_token=NULL,lease_until=NULL,error_message=NULL
     WHERE id=v_task.id;
    PERFORM private.dashboard_goal_refresh_sync_run(v_task.run_id);
    RETURN jsonb_build_object('ok',true,'task_id',v_task.id,'run_id',v_task.run_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_dashboard_goal_refresh_fail(p_task_id uuid,p_lease_token uuid,p_error text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_run_id uuid;
BEGIN
    PERFORM private.evolution_assert_admin();
    UPDATE private.dashboard_goal_refresh_tasks
       SET status=CASE WHEN attempts>=3 THEN 'failed' ELSE 'queued' END,
           error_message=left(coalesce(nullif(p_error,''),'Falha sem detalhes retornados.'),1000),
           lease_token=NULL,lease_until=NULL,updated_at=clock_timestamp()
     WHERE id=p_task_id AND status='processing' AND lease_token=p_lease_token
     RETURNING run_id INTO v_run_id;
    IF v_run_id IS NOT NULL THEN PERFORM private.dashboard_goal_refresh_sync_run(v_run_id); END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_dashboard_goal_refresh_status(p_run_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_result jsonb;
BEGIN
    PERFORM private.evolution_assert_admin();
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id',r.id,'created_at',r.created_at,'updated_at',r.updated_at,'completed_at',r.completed_at,
        'status',r.status,'task_count',r.task_count,'completed_count',r.completed_count,'failed_count',r.failed_count,
        'error_summary',r.error_summary,
        'tasks',(SELECT coalesce(jsonb_agg(jsonb_build_object(
            'type',t.task_type,'year',t.ano,'month',t.mes,'status',t.status,'attempts',t.attempts,
            'started_at',t.started_at,'completed_at',t.completed_at,'error_message',t.error_message
        ) ORDER BY CASE t.task_type WHEN 'summary' THEN 0 ELSE 1 END,t.ano,t.mes),'[]'::jsonb)
          FROM private.dashboard_goal_refresh_tasks t WHERE t.run_id=r.id)
    ) ORDER BY r.created_at DESC),'[]'::jsonb)
      INTO v_result FROM private.dashboard_goal_refresh_runs r
     WHERE r.created_at>=clock_timestamp()-interval '3 days'
       AND (p_run_id IS NULL OR r.id=p_run_id);
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.elma_dashboard_goal_refresh_retry(p_run_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_count integer;
BEGIN
    PERFORM private.evolution_assert_admin();
    UPDATE private.dashboard_goal_refresh_tasks
       SET status='queued',attempts=0,lease_token=NULL,lease_until=NULL,error_message=NULL,
           completed_at=NULL,updated_at=clock_timestamp()
     WHERE run_id=p_run_id AND status='failed';
    GET DIAGNOSTICS v_count=ROW_COUNT;
    IF NOT EXISTS(SELECT 1 FROM private.dashboard_goal_refresh_runs WHERE id=p_run_id) THEN
        RAISE EXCEPTION 'Atualização não encontrada.' USING ERRCODE='P0002';
    END IF;
    UPDATE private.dashboard_goal_refresh_runs SET completed_at=NULL,error_summary=NULL,updated_at=clock_timestamp() WHERE id=p_run_id;
    PERFORM private.dashboard_goal_refresh_sync_run(p_run_id);
    RETURN jsonb_build_object('job_id',p_run_id,'requeued',v_count);
END;
$function$;

-- The cron worker is the durable backstop if the browser closes or an Edge invocation expires.
CREATE OR REPLACE FUNCTION private.dashboard_goal_refresh_process_next()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_task private.dashboard_goal_refresh_tasks%ROWTYPE; v_token uuid;
BEGIN
    UPDATE private.dashboard_goal_refresh_tasks
       SET status=CASE WHEN attempts>=3 THEN 'failed' ELSE 'queued' END,
           error_message=coalesce(error_message,'O prazo da tarefa expirou; foi liberada para retomada.'),
           lease_token=NULL,lease_until=NULL,updated_at=clock_timestamp()
     WHERE status='processing' AND lease_until<clock_timestamp();

    SELECT * INTO v_task FROM private.dashboard_goal_refresh_tasks
     WHERE status='queued'
     ORDER BY created_at,CASE task_type WHEN 'summary' THEN 0 ELSE 1 END,ano,mes
     FOR UPDATE SKIP LOCKED LIMIT 1;
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

CREATE OR REPLACE FUNCTION private.dashboard_goal_refresh_cleanup()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
    DELETE FROM private.dashboard_goal_refresh_runs WHERE created_at<clock_timestamp()-interval '3 days';
$function$;

REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_sync_run(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_apply(text,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_process_next() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_cleanup() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.elma_enqueue_dashboard_goal_refresh(jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.elma_dashboard_goal_refresh_claim(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.elma_dashboard_goal_refresh_process(uuid,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.elma_dashboard_goal_refresh_fail(uuid,uuid,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.elma_dashboard_goal_refresh_status(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.elma_dashboard_goal_refresh_retry(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.elma_enqueue_dashboard_goal_refresh(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elma_dashboard_goal_refresh_claim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elma_dashboard_goal_refresh_process(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elma_dashboard_goal_refresh_fail(uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elma_dashboard_goal_refresh_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.elma_dashboard_goal_refresh_retry(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.dashboard_goal_refresh_process_next() TO postgres,supabase_admin;
GRANT EXECUTE ON FUNCTION private.dashboard_goal_refresh_cleanup() TO postgres,supabase_admin;

DO $schedule$
DECLARE v_job record;
BEGIN
    FOR v_job IN SELECT jobid FROM cron.job
                  WHERE jobname IN ('dashboard-goal-refresh-worker','dashboard-goal-refresh-cleanup')
    LOOP
        PERFORM cron.unschedule(v_job.jobid);
    END LOOP;
    PERFORM cron.schedule('dashboard-goal-refresh-worker','* * * * *','SELECT private.dashboard_goal_refresh_process_next()');
    PERFORM cron.schedule('dashboard-goal-refresh-cleanup','17 * * * *','SELECT private.dashboard_goal_refresh_cleanup()');
END;
$schedule$;
