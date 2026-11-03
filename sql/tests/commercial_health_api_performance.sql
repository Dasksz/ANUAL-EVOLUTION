BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='8s';
SET LOCAL plan_cache_mode='force_generic_plan';
-- Same scalar JSON envelope and prepared arguments used by PostgREST.
PREPARE health_api(json,integer,integer) AS
WITH pgrst_source AS (
 SELECT pgrst_call.pgrst_scalar FROM(SELECT $1 AS json_data)pgrst_payload,
 LATERAL(SELECT p_month FROM json_to_record(pgrst_payload.json_data) AS _(p_month text) LIMIT 1)pgrst_body,
 LATERAL(SELECT public.get_commercial_health_month_v1(p_month:=pgrst_body.p_month)pgrst_scalar)pgrst_call)
 SELECT coalesce(json_agg(_postgrest_t.pgrst_scalar)->0,'null') body
 FROM(SELECT get_commercial_health_month_v1.* FROM pgrst_source AS get_commercial_health_month_v1 LIMIT $2 OFFSET $3)_postgrest_t;
DO $$DECLARE started timestamptz:=clock_timestamp();d json;BEGIN
 EXECUTE 'EXECUTE health_api(''{"p_month":null}'',1,0)' INTO d;
 IF d->>'source'<>'database' OR json_array_length(d->'rows')=0 THEN RAISE EXCEPTION 'Invalid API body';END IF;
 PERFORM set_config('health.api_ms',(1000*extract(epoch FROM clock_timestamp()-started))::text,true);
 PERFORM set_config('health.api_month',d->>'competence',true);
END;$$;
SELECT current_setting('health.api_ms')::numeric api_ms,current_setting('health.api_month') competence;
DEALLOCATE health_api;
ROLLBACK;
