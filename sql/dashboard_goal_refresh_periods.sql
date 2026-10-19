-- Return only months with source rows. Client/dimension changes should not enqueue
-- twelve empty summary rebuilds for every historical year.
CREATE OR REPLACE FUNCTION public.elma_get_dashboard_refresh_periods()
RETURNS TABLE (ano integer, mes integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    PERFORM private.evolution_assert_admin();
    RETURN QUERY
    SELECT DISTINCT s.ano::integer, s.mes::integer
      FROM public.data_summary s
     WHERE s.ano BETWEEN 1 AND 9998 AND s.mes BETWEEN 1 AND 12
     ORDER BY s.ano, s.mes;
END;
$function$;

REVOKE ALL ON FUNCTION public.elma_get_dashboard_refresh_periods() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.elma_get_dashboard_refresh_periods() TO authenticated;

-- A full historical source may span more than twenty years; the queue, rather
-- than the request timeout, is the bound on how much work can be scheduled.
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
    IF jsonb_typeof(p_periods) <> 'array' OR jsonb_array_length(p_periods)>1200 THEN
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

        -- A historical sale in month S can change the rolling goal split in S+1..S+3.
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

REVOKE ALL ON FUNCTION public.elma_enqueue_dashboard_goal_refresh(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.elma_enqueue_dashboard_goal_refresh(jsonb) TO authenticated;

-- Keep the run summary accurate when the cron backstop expires stale leases.
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
REVOKE ALL ON FUNCTION private.dashboard_goal_refresh_process_next() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.dashboard_goal_refresh_process_next() TO postgres, supabase_admin;
