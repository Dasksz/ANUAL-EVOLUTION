BEGIN;
CREATE TEMP TABLE health_baseline_guard(x integer) ON COMMIT DROP;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL statement_timeout='30s';
CREATE OR REPLACE FUNCTION pg_temp.health_baseline(p_month text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog SET statement_timeout='30s' AS $$
DECLARE target date;available jsonb;periods jsonb;result_rows jsonb;source_revision uuid;source_updated timestamptz;asof date;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501';END IF;
 IF p_month IS NOT NULL AND p_month~'^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
 PERFORM private.commercial_health_require_ready_v1(((p_month||'-01')::date-interval '5 months')::date,(p_month||'-01')::date,false);END IF;
 SELECT revision,changed_at INTO source_revision,source_updated FROM public.commercial_health_source_state WHERE id=true;
 WITH months AS MATERIALIZED(SELECT DISTINCT month_date m FROM private.commercial_health_sales_source_v1),eligible AS(
 SELECT m FROM months a WHERE (SELECT count(*) FROM months b WHERE b.m BETWEEN (a.m-interval '5 months')::date AND a.m)=6)
 SELECT coalesce(jsonb_agg(to_char(m,'YYYY-MM') ORDER BY m DESC),'[]'),max(m) INTO available,target FROM eligible;
 IF p_month IS NULL THEN PERFORM private.commercial_health_require_ready_v1((target-interval '5 months')::date,target,true);END IF;
 IF p_month IS NOT NULL THEN
  IF p_month!~'^[0-9]{4}-(0[1-9]|1[0-2])$' OR NOT available ? p_month THEN RAISE EXCEPTION 'Competência sem carga de vendas ou histórico suficiente' USING ERRCODE='22023';END IF;
  target:=(p_month||'-01')::date;
 END IF;
 IF target IS NULL THEN RAISE EXCEPTION 'Aguardando vendas e cinco meses anteriores de histórico';END IF;
 SELECT jsonb_agg(to_char(target-(5-i)*interval '1 month','YYYY-MM') ORDER BY i) INTO periods FROM generate_series(0,5)i;
 WITH raw AS MATERIALIZED(SELECT * FROM private.commercial_health_sales_source_v1 WHERE month_date BETWEEN (target-interval '5 months')::date AND target),
 monthly AS MATERIALIZED(SELECT codcli,month_date,sum(vlvenda) amount,count(DISTINCT produto) FILTER(WHERE tipovenda IN('1','9') AND vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL) mix FROM raw GROUP BY 1,2),
 latest AS(SELECT DISTINCT ON(codcli) codcli,codusur,codsupervisor FROM raw ORDER BY codcli,sale_date DESC,codusur,codsupervisor),
 matrix AS(SELECT l.codcli,l.codusur,l.codsupervisor,array_agg(coalesce(a.amount,0) ORDER BY i) values_array,array_agg(coalesce(a.mix,0) ORDER BY i) mix_array
 FROM latest l CROSS JOIN generate_series(0,5)i LEFT JOIN monthly a ON a.codcli=l.codcli AND a.month_date=(target-(5-i)*interval '1 month')::date GROUP BY 1,2,3),
 measures AS(SELECT x.*,(SELECT avg(v) FROM unnest(values_array[1:4])v) avg_value,
 (SELECT percentile_cont(.5) WITHIN GROUP(ORDER BY v)::numeric FROM unnest(values_array[1:4])v) median_value,
 (SELECT count(*) FROM unnest(values_array[1:4])v WHERE v>=.01) positive_months,
 (SELECT max(v) FROM unnest(values_array[1:4])v) max_value,
 (mix_array[1]+mix_array[2]+mix_array[3]+mix_array[4])::numeric/4 mix_historical,mix_array[5] mix_previous FROM matrix x),
 base_class AS(SELECT x.*,CASE WHEN values_array[6]>=.01 OR positive_months<2 OR median_value<=0 OR values_array[5]<median_value*1.3 THEN 'SEM ALERTA'
 WHEN values_array[5]>=max_value*1.3 THEN 'CRÍTICO' ELSE 'ANALISAR' END source_status FROM measures x),
 assigned AS(SELECT x.*,coalesce(nullif(c.nomecliente,''),'Cliente '||x.codcli) client_name,
 CASE WHEN coalesce(nullif(c.rca1,''),x.codusur)='267' THEN '321' ELSE coalesce(nullif(c.rca1,''),x.codusur,'') END seller_code,
 CASE WHEN coalesce(nullif(c.rca1,''),x.codusur)='267' THEN '21' ELSE coalesce(nullif(c.codsupervisor,''),x.codsupervisor,'') END supervisor_code
 FROM base_class x LEFT JOIN public.data_clients c ON c.codigo_cliente=x.codcli),
 classified AS(SELECT x.*,source_status='CRÍTICO' AND mix_historical>0 AND mix_previous>=mix_historical*1.5 expanded FROM assigned x)
 SELECT jsonb_agg(jsonb_build_object('code',x.codcli,'name',client_name,'history',to_jsonb(values_array[1:4]),'average',avg_value,'median',median_value,
 'previous',values_array[5],'current',values_array[6],'variation',CASE WHEN median_value>0 THEN values_array[5]/median_value-1 ELSE NULL END,
 'positiveMonths',positive_months,'excess',greatest(0,values_array[5]-median_value),'sourceStatus',source_status,
 'status',CASE WHEN expanded THEN 'ANALISAR' ELSE source_status END,'mixReclassified',expanded,'mixHistorical',mix_historical,'mixPrevious',mix_previous,
 'sellerCode',seller_code,'seller',coalesce(nullif(v.nome,''),nullif(seller_code,''),'Não informado'),
 'supervisorCode',supervisor_code,'supervisor',coalesce(nullif(s.nome,''),nullif(supervisor_code,''),'Não informado')) ORDER BY x.codcli),
 (SELECT max(sale_date) FROM raw WHERE month_date=target)
 INTO result_rows,asof FROM classified x LEFT JOIN public.dim_vendedores v ON v.codigo=x.seller_code LEFT JOIN public.dim_supervisores s ON s.codigo=x.supervisor_code;
 RETURN jsonb_build_object('schema_version',1,'source','database','competence',to_char(target,'YYYY-MM'),'availableMonths',available,'historyComplete',true,
 'periods',periods,'rows',coalesce(result_rows,'[]'),'asOf',asof,'syncedAt',source_updated,'calculatedAt',statement_timestamp(),'mixVersion',source_revision,'syncError',false,'duplicatesMerged',0);
END;$$;

DO $$DECLARE before_data jsonb;after_data jsonb;m text;BEGIN
 FOREACH m IN ARRAY ARRAY['2026-10','2026-11'] LOOP
 before_data:=pg_temp.health_baseline(m);after_data:=public.get_commercial_health_month_v1(m);
 IF (before_data-'calculatedAt') IS DISTINCT FROM (after_data-'calculatedAt') THEN RAISE EXCEPTION 'Results changed for %',m;END IF;
 END LOOP;
END;$$;
SELECT 'October and November payloads match the pre-optimization calculation exactly' result;
ROLLBACK;
