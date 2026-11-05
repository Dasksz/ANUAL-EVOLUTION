BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated; SET LOCAL statement_timeout='8s'; SET LOCAL plan_cache_mode='force_generic_plan';
PREPARE mix_api(json,integer,integer) AS
WITH pgrst_source AS (
 SELECT call.pgrst_scalar FROM (SELECT $1 AS json_data)payload,
 LATERAL(SELECT * FROM json_to_record(payload.json_data) AS _(p_ano text,p_mes text,p_cidade text[],p_filial text[],p_supervisor text[],p_vendedor text[],p_fornecedor text[],p_rede text[],p_produto text[],p_categoria text[],p_tipovenda text[]) LIMIT 1)body,
 LATERAL(SELECT public.get_mix_salty_foods_data(p_ano:=body.p_ano,p_mes:=body.p_mes,p_cidade:=body.p_cidade,p_filial:=body.p_filial,p_supervisor:=body.p_supervisor,p_vendedor:=body.p_vendedor,p_fornecedor:=body.p_fornecedor,p_rede:=body.p_rede,p_produto:=body.p_produto,p_categoria:=body.p_categoria,p_tipovenda:=body.p_tipovenda)pgrst_scalar)call)
 SELECT coalesce(json_agg(x.pgrst_scalar)->0,'null') FROM(SELECT * FROM pgrst_source LIMIT $2 OFFSET $3)x;
DO $$DECLARE started timestamptz:=clock_timestamp();d json;BEGIN
 EXECUTE 'EXECUTE mix_api(''{"p_ano":"2026","p_mes":null}'',1,0)' INTO d;
 IF d->>'current_year'<>'2026' OR json_array_length(d->'chart_data')=0 THEN RAISE EXCEPTION 'Invalid mix API body';END IF;
 PERFORM set_config('mix.api_ms',(1000*extract(epoch FROM clock_timestamp()-started))::text,true);
 PERFORM set_config('mix.result',d::text,true);
END;$$;
SELECT current_setting('mix.api_ms')::numeric api_ms,current_setting('mix.result')::json response;
DEALLOCATE mix_api; ROLLBACK;
