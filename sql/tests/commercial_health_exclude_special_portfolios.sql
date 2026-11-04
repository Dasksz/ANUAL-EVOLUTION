BEGIN;
CREATE TEMP TABLE health_scope_test_guard(x integer) ON COMMIT DROP;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
CREATE OR REPLACE FUNCTION pg_temp.health_before_exclusions(p_month text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog SET statement_timeout='30s' AS $$
DECLARE target date;available jsonb;periods jsonb;result_rows jsonb;source_revision uuid;source_updated timestamptz;asof date;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501';END IF;
 IF p_month IS NOT NULL AND p_month~'^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
 PERFORM private.commercial_health_require_ready_v1(((p_month||'-01')::date-interval '5 months')::date,(p_month||'-01')::date,false);END IF;
 SELECT revision,changed_at INTO source_revision,source_updated FROM public.commercial_health_source_state WHERE id=true;
 -- Probe indexed date ranges instead of projecting every historical row.
 WITH bounds AS(SELECT date_trunc('month',least((SELECT min(dtped) FROM public.data_detailed),(SELECT min(dtped) FROM public.data_history)) AT TIME ZONE 'UTC') first_month,
 date_trunc('month',greatest((SELECT max(dtped) FROM public.data_detailed),(SELECT max(dtped) FROM public.data_history)) AT TIME ZONE 'UTC') last_month),
 candidates AS(SELECT g::date m FROM bounds CROSS JOIN LATERAL generate_series(first_month,last_month,interval '1 month')g),
 months AS MATERIALIZED(SELECT m FROM candidates c WHERE
 EXISTS(SELECT 1 FROM public.data_detailed d WHERE d.dtped>=c.m::timestamp AT TIME ZONE 'UTC' AND d.dtped<(c.m+interval '1 month')::timestamp AT TIME ZONE 'UTC'
 AND d.tipovenda NOT IN('5','11') AND ltrim(d.codfor,'0') IN('707','708','752','1119') AND d.codcli~'^[0-9]+$' AND d.codcli::numeric>0)
 OR(NOT EXISTS(SELECT 1 FROM public.data_detailed d WHERE d.dtped>=c.m::timestamp AT TIME ZONE 'UTC' AND d.dtped<(c.m+interval '1 month')::timestamp AT TIME ZONE 'UTC')
 AND EXISTS(SELECT 1 FROM public.data_history h WHERE h.dtped>=c.m::timestamp AT TIME ZONE 'UTC' AND h.dtped<(c.m+interval '1 month')::timestamp AT TIME ZONE 'UTC'
 AND h.tipovenda NOT IN('5','11') AND ltrim(h.codfor,'0') IN('707','708','752','1119') AND h.codcli~'^[0-9]+$' AND h.codcli::numeric>0))),
 eligible AS(SELECT m FROM months a WHERE (SELECT count(*) FROM months b WHERE b.m BETWEEN (a.m-interval '5 months')::date AND a.m)=6)
 SELECT coalesce(jsonb_agg(to_char(m,'YYYY-MM') ORDER BY m DESC),'[]'),max(m) INTO available,target FROM eligible;
 IF p_month IS NULL THEN PERFORM private.commercial_health_require_ready_v1((target-interval '5 months')::date,target,true);END IF;
 IF p_month IS NOT NULL THEN
  IF p_month!~'^[0-9]{4}-(0[1-9]|1[0-2])$' OR NOT available ? p_month THEN RAISE EXCEPTION 'Competência sem carga de vendas ou histórico suficiente' USING ERRCODE='22023';END IF;
  target:=(p_month||'-01')::date;
 END IF;
 IF target IS NULL THEN RAISE EXCEPTION 'Aguardando vendas e cinco meses anteriores de histórico';END IF;
 SELECT jsonb_agg(to_char(target-(5-i)*interval '1 month','YYYY-MM') ORDER BY i) INTO periods FROM generate_series(0,5)i;
 WITH raw AS MATERIALIZED(SELECT * FROM private.commercial_health_sales_source_v1 WHERE source_timestamp>=(target-interval '5 months')::timestamp AT TIME ZONE 'UTC' AND source_timestamp<(target+interval '1 month')::timestamp AT TIME ZONE 'UTC'),
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

DO $$DECLARE old_data jsonb;new_data jsonb;expected jsonb;month text;BEGIN
 FOREACH month IN ARRAY ARRAY['2026-10','2026-09'] LOOP
  old_data:=pg_temp.health_before_exclusions(month);
  new_data:=public.get_commercial_health_month_v1(month);
  SELECT coalesce(jsonb_agg(r ORDER BY r->>'code'),'[]') INTO expected FROM jsonb_array_elements(old_data->'rows')r
  WHERE upper(ltrim(btrim(r->>'sellerCode'),'0')) NOT IN('53','BALCAO','BALCAO_SP','AMERICANAS')
  AND upper(btrim(r->>'seller')) !~ '^(AMERICANAS|BALC[ÃA]O)([[:space:]_/.-]|$)';
  IF jsonb_array_length(expected)>=jsonb_array_length(old_data->'rows') THEN RAISE EXCEPTION 'Fixture did not cover exclusions';END IF;
  IF new_data->'rows' IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Other customers or calculations changed for %',month;END IF;
  IF (new_data-'rows'-'calculatedAt') IS DISTINCT FROM (old_data-'rows'-'calculatedAt') THEN RAISE EXCEPTION 'Metadata changed';END IF;
 END LOOP;
END;$$;
SELECT 'Only Americanas and Balcão portfolios removed; retained customers match exactly in October and September' result;
ROLLBACK;
