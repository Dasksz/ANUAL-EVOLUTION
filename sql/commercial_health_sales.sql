-- Database-backed, recalculable commercial health. Four historical months,
-- one comparison month, and one followed month. No Sheets/network dependency.
CREATE TABLE IF NOT EXISTS public.commercial_health_source_state(
 id boolean PRIMARY KEY DEFAULT true CHECK(id),revision uuid NOT NULL DEFAULT gen_random_uuid(),changed_at timestamptz NOT NULL DEFAULT clock_timestamp());
INSERT INTO public.commercial_health_source_state(id) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE public.commercial_health_source_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commercial_health_source_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.commercial_health_source_state TO authenticated;
CREATE POLICY commercial_health_source_read ON public.commercial_health_source_state FOR SELECT TO authenticated USING((SELECT public.is_approved()));
CREATE OR REPLACE FUNCTION private.commercial_health_source_changed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN UPDATE public.commercial_health_source_state SET revision=gen_random_uuid(),changed_at=clock_timestamp() WHERE id=true;RETURN NULL;END;$$;
REVOKE ALL ON FUNCTION private.commercial_health_source_changed() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER commercial_health_sales_changed AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.data_detailed FOR EACH STATEMENT EXECUTE FUNCTION private.commercial_health_source_changed();
CREATE TRIGGER commercial_health_history_changed AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.data_history FOR EACH STATEMENT EXECUTE FUNCTION private.commercial_health_source_changed();
CREATE TRIGGER commercial_health_portfolio_changed AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.data_clients FOR EACH STATEMENT EXECUTE FUNCTION private.commercial_health_source_changed();

-- Current uploads take precedence for the WHOLE month when also in history.
-- This prevents double counting while allowing current-month corrections.
CREATE OR REPLACE VIEW private.commercial_health_sales_source_v1 WITH(security_invoker=true) AS
 WITH current_months AS MATERIALIZED(SELECT DISTINCT date_trunc('month',dtped AT TIME ZONE 'UTC')::date m FROM public.data_detailed)
 SELECT (d.dtped AT TIME ZONE 'UTC')::date sale_date,date_trunc('month',d.dtped AT TIME ZONE 'UTC')::date month_date,
 d.codcli,d.codusur,d.codsupervisor,d.codfor,d.tipovenda,d.vlvenda,d.qtvenda,d.produto
 FROM public.data_detailed d WHERE d.tipovenda NOT IN('5','11') AND ltrim(d.codfor,'0') IN('707','708','752','1119') AND d.codcli~'^[0-9]+$' AND d.codcli::numeric>0
 UNION ALL
 SELECT (h.dtped AT TIME ZONE 'UTC')::date,date_trunc('month',h.dtped AT TIME ZONE 'UTC')::date,
 h.codcli,h.codusur,h.codsupervisor,h.codfor,h.tipovenda,h.vlvenda,h.qtvenda,h.produto
 FROM public.data_history h WHERE h.tipovenda NOT IN('5','11') AND ltrim(h.codfor,'0') IN('707','708','752','1119') AND h.codcli~'^[0-9]+$' AND h.codcli::numeric>0
 AND NOT EXISTS(SELECT 1 FROM current_months c WHERE h.dtped>=c.m::timestamp AT TIME ZONE 'UTC' AND h.dtped<(c.m+interval '1 month')::timestamp AT TIME ZONE 'UTC');
REVOKE ALL ON private.commercial_health_sales_source_v1 FROM PUBLIC,anon,authenticated;

-- Raw uploads are staged over several requests; do not read a partial chunk.
-- raw_complete is sufficient: this panel does not wait for summary refreshes.
CREATE OR REPLACE FUNCTION private.commercial_health_require_ready_v1(p_start date,p_end date,p_latest boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM elma_ops.loads WHERE table_name IN('data_detailed','data_history') AND state='loading'
 AND(p_start IS NULL OR chunk_key>=to_char(p_start,'YYYY-MM')) AND(p_latest OR chunk_key<=to_char(p_end,'YYYY-MM'))) THEN
 RAISE EXCEPTION 'As vendas ainda estão sendo enviadas. Aguarde a conclusão da carga.' USING ERRCODE='55000';END IF;
END;$$;
REVOKE ALL ON FUNCTION private.commercial_health_require_ready_v1(date,date,boolean) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.commercial_health_month_read_v1(p_month text DEFAULT NULL)
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
REVOKE ALL ON FUNCTION private.commercial_health_month_read_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.commercial_health_month_read_v1(text) TO authenticated;

CREATE OR REPLACE FUNCTION private.commercial_health_mix_read_v1(p_client_code text,p_month text,p_version uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog SET statement_timeout='15s' AS $$
DECLARE target date;version uuid;periods jsonb;skus jsonb;document jsonb;monthly jsonb;avg_mix numeric;prev_mix integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501';END IF;
 IF p_month IS NULL OR p_month!~'^[0-9]{4}-(0[1-9]|1[0-2])$' OR p_client_code IS NULL OR p_client_code!~'^[0-9]+$' THEN RAISE EXCEPTION 'Cliente ou competência inválida' USING ERRCODE='22023';END IF;
 SELECT revision INTO version FROM public.commercial_health_source_state WHERE id=true;
 IF p_version IS NOT NULL AND p_version<>version THEN RAISE EXCEPTION 'Vendas ou carteira atualizadas. Atualize o painel e tente novamente.';END IF;
 target:=(p_month||'-01')::date;
 PERFORM private.commercial_health_require_ready_v1((target-interval '5 months')::date,target,false);
 IF NOT EXISTS(SELECT 1 FROM private.commercial_health_sales_source_v1 WHERE month_date=target) THEN RAISE EXCEPTION 'Competência sem vendas';END IF;
 SELECT jsonb_agg(to_char(target-(5-i)*interval '1 month','YYYY-MM') ORDER BY i) INTO periods FROM generate_series(0,4)i;
 WITH presence AS(SELECT produto,jsonb_build_array(bool_or(month_date=(target-interval '5 months')::date),bool_or(month_date=(target-interval '4 months')::date),bool_or(month_date=(target-interval '3 months')::date),bool_or(month_date=(target-interval '2 months')::date),bool_or(month_date=(target-interval '1 month')::date)) months
 FROM private.commercial_health_sales_source_v1 WHERE codcli=p_client_code AND month_date BETWEEN (target-interval '5 months')::date AND (target-interval '1 month')::date
 AND tipovenda IN('1','9') AND vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL GROUP BY produto)
 SELECT coalesce(jsonb_agg(jsonb_build_object('code',p.produto,'name',coalesce(nullif(d.descricao,''),p.produto),'months',p.months) ORDER BY p.produto),'[]') INTO skus FROM presence p LEFT JOIN public.dim_produtos d ON d.codigo=p.produto;
 SELECT jsonb_agg(n ORDER BY i) INTO monthly FROM(SELECT i,(SELECT count(*) FROM jsonb_array_elements(skus)s WHERE s->'months'->i='true')n FROM generate_series(0,4)i)t;
 SELECT avg(v::numeric) INTO avg_mix FROM jsonb_array_elements_text(monthly) WITH ORDINALITY t(v,i) WHERE i<=4;
 prev_mix:=(monthly->>4)::integer;
 RETURN jsonb_build_object('periods',periods,'monthlyCounts',monthly,'historicalAverage',avg_mix,'previousAverage',prev_mix,'skus',skus,'version',version,'clientCode',p_client_code,'competence',p_month);
END;$$;
REVOKE ALL ON FUNCTION private.commercial_health_mix_read_v1(text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.commercial_health_mix_read_v1(text,text,uuid) TO authenticated;

-- Private readers authorize approved accounts once before aggregating raw rows.
-- No arbitrary SQL/filters and no SECURITY DEFINER endpoint in the exposed schema.
CREATE OR REPLACE FUNCTION public.get_commercial_health_month_v1(p_month text DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT private.commercial_health_month_read_v1(p_month);$$;
REVOKE ALL ON FUNCTION public.get_commercial_health_month_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_commercial_health_month_v1(text) TO authenticated;
CREATE OR REPLACE FUNCTION public.get_commercial_health_mix_month_v1(p_client_code text,p_month text,p_version uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT private.commercial_health_mix_read_v1(p_client_code,p_month,p_version);$$;
REVOKE ALL ON FUNCTION public.get_commercial_health_mix_month_v1(text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_commercial_health_mix_month_v1(text,text,uuid) TO authenticated;

-- Compatibility for already-open clients; no legacy endpoint reads Sheets again.
CREATE OR REPLACE FUNCTION public.get_commercial_health_v1() RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT public.get_commercial_health_month_v1(NULL);$$;
CREATE OR REPLACE FUNCTION public.get_commercial_health_mix_v1(p_client_code text,p_version uuid DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT public.get_commercial_health_mix_month_v1(p_client_code,(public.get_commercial_health_month_v1(NULL)->>'competence'),p_version);$$;
CREATE OR REPLACE FUNCTION private.sync_commercial_health_from_sheet() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT jsonb_build_object('status','database-backed','message','Saúde Comercial recalculada diretamente das vendas; leitura da planilha desativada');$$;
REVOKE ALL ON FUNCTION private.sync_commercial_health_from_sheet() FROM PUBLIC,anon,authenticated;
DO $$DECLARE j record;BEGIN FOR j IN SELECT jobid FROM cron.job WHERE jobname='sync-commercial-health' AND command='select private.sync_commercial_health_from_sheet();' LOOP PERFORM cron.unschedule(j.jobid);END LOOP;END;$$;
