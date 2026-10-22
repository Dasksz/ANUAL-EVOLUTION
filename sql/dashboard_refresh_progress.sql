CREATE OR REPLACE FUNCTION public.get_dashboard_refresh_progress()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE r private.dashboard_goal_refresh_runs%ROWTYPE;
BEGIN
 PERFORM private.evolution_assert_approved();
 SELECT * INTO r FROM private.dashboard_goal_refresh_runs
 WHERE status IN ('queued','processing') OR created_at >= now()-interval '24 hours'
 ORDER BY CASE WHEN status IN ('queued','processing') THEN 0 ELSE 1 END,created_at DESC LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('status',r.status,'total',r.task_count,'completed',r.completed_count,
  'failed',r.failed_count,'revision',r.id::text||':'||r.status,'updated_at',r.updated_at);
END; $$;
REVOKE ALL ON FUNCTION public.get_dashboard_refresh_progress() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_refresh_progress() TO authenticated;
