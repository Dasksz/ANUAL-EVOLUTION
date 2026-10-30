-- Apply after commercial_health.sql. Mix is prepared during background sync, not page reads.
BEGIN;
CREATE TABLE IF NOT EXISTS public.commercial_health_mix_cache (
 client_code text PRIMARY KEY, version uuid NOT NULL, payload jsonb NOT NULL, updated_at timestamptz NOT NULL
);
ALTER TABLE public.commercial_health_mix_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commercial_health_mix_cache FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.commercial_health_mix_cache TO authenticated;
DROP POLICY IF EXISTS commercial_health_mix_read ON public.commercial_health_mix_cache;
CREATE POLICY commercial_health_mix_read ON public.commercial_health_mix_cache FOR SELECT TO authenticated USING ((SELECT public.is_approved()));

CREATE OR REPLACE FUNCTION private.commercial_health_mix_document(periods jsonb,available jsonb,skus jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE monthly jsonb:='[]'; i integer; n integer; total integer:=0; complete boolean:=true; previous integer;
BEGIN
 FOR i IN 0..4 LOOP
  IF available->i='true'::jsonb THEN
   SELECT count(*) INTO n FROM jsonb_array_elements(skus) r WHERE r->'months'->i='true'::jsonb;
   monthly:=monthly||jsonb_build_array(n);
   IF i<4 THEN total:=total+n; ELSE previous:=n; END IF;
  ELSE
   monthly:=monthly||'[null]'::jsonb;
   IF i<4 THEN complete:=false; END IF;
  END IF;
 END LOOP;
 RETURN jsonb_build_object('periods',periods,'monthlyCounts',monthly,'historicalAverage',CASE WHEN complete THEN total::numeric/4 ELSE NULL END,'previousAverage',previous,'skus',skus);
END;$$;
REVOKE ALL ON FUNCTION private.commercial_health_mix_document(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;

-- Preserve the Sheets classification so later mix updates can reverse an override.
CREATE OR REPLACE FUNCTION private.commercial_health_mix_classify(r jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 WITH rule AS (
  SELECT coalesce(r->>'sourceStatus',r->>'status') source_status,
   coalesce(coalesce(r->>'sourceStatus',r->>'status')='CRÍTICO' AND (r->>'mixHistorical')::numeric>0 AND (r->>'mixPrevious')::numeric>=(r->>'mixHistorical')::numeric*1.5,false) expanded
 )
 SELECT r||jsonb_build_object('sourceStatus',source_status,'status',CASE WHEN expanded THEN 'ANALISAR' ELSE source_status END,'mixReclassified',expanded) FROM rule;
$$;
REVOKE ALL ON FUNCTION private.commercial_health_mix_classify(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.commercial_health_mix_refresh(p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE periods jsonb; first_day timestamptz; last_day timestamptz; generation uuid:=gen_random_uuid(); result_rows jsonb;
BEGIN
 SELECT jsonb_agg(v ORDER BY ord) INTO periods FROM jsonb_array_elements(p->'periods') WITH ORDINALITY t(v,ord) WHERE ord<=5;
 IF jsonb_array_length(periods) IS DISTINCT FROM 5 THEN RAISE EXCEPTION 'Períodos do mix inválidos'; END IF;
 first_day:=((periods->>0)||'-01T00:00:00Z')::timestamptz;
 last_day:=(((periods->>4)||'-01')::date+interval '1 month')::timestamp AT TIME ZONE 'UTC';
 PERFORM pg_advisory_xact_lock(17890101,851597314);
 DELETE FROM public.commercial_health_mix_cache WHERE client_code IS NOT NULL;
 WITH raw AS MATERIALIZED (
  SELECT codcli,produto,to_char(dtped AT TIME ZONE 'UTC','YYYY-MM') month_key,tipovenda,qtvenda,vlvenda FROM public.data_history WHERE dtped>=first_day AND dtped<last_day
  UNION ALL
  SELECT codcli,produto,to_char(dtped AT TIME ZONE 'UTC','YYYY-MM'),tipovenda,qtvenda,vlvenda FROM public.data_detailed WHERE dtped>=first_day AND dtped<last_day
 ), coverage AS (
  SELECT jsonb_agg(EXISTS(SELECT 1 FROM raw WHERE month_key=v) ORDER BY ord) available FROM jsonb_array_elements_text(periods) WITH ORDINALITY t(v,ord)
 ), presence AS (
  SELECT codcli,produto,jsonb_build_array(bool_or(month_key=periods->>0),bool_or(month_key=periods->>1),bool_or(month_key=periods->>2),bool_or(month_key=periods->>3),bool_or(month_key=periods->>4)) months
  FROM raw WHERE tipovenda IN ('1','9') AND vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL GROUP BY codcli,produto
 ), products AS (
  SELECT f.codcli,jsonb_agg(jsonb_build_object('code',f.produto,'name',coalesce(nullif(d.descricao,''),f.produto),'months',f.months) ORDER BY f.produto) skus
  FROM presence f LEFT JOIN public.dim_produtos d ON d.codigo=f.produto GROUP BY f.codcli
 )
 INSERT INTO public.commercial_health_mix_cache(client_code,version,payload,updated_at)
 SELECT r->>'code',generation,private.commercial_health_mix_document(periods,c.available,coalesce(f.skus,'[]'::jsonb)),clock_timestamp()
 FROM jsonb_array_elements(p->'rows') r CROSS JOIN coverage c LEFT JOIN products f ON f.codcli=r->>'code';
 SELECT jsonb_agg(private.commercial_health_mix_classify(r||jsonb_build_object('mixHistorical',c.payload->'historicalAverage','mixPrevious',c.payload->'previousAverage')) ORDER BY r->>'code') INTO result_rows
 FROM jsonb_array_elements(p->'rows') r JOIN public.commercial_health_mix_cache c ON c.client_code=r->>'code' AND c.version=generation;
 RETURN jsonb_set(p,'{rows}',result_rows)||jsonb_build_object('mixVersion',generation);
END;$$;
REVOKE ALL ON FUNCTION private.commercial_health_mix_refresh(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_commercial_health_mix_v1(p_client_code text,p_version uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE detail jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 SELECT payload||jsonb_build_object('version',version,'clientCode',client_code) INTO detail FROM public.commercial_health_mix_cache
 WHERE client_code=p_client_code AND (p_version IS NULL OR version=p_version);
 IF detail IS NULL THEN RAISE EXCEPTION 'Dados de mix atualizados. Atualize o painel para consultar novamente.'; END IF;
 RETURN detail;
END;$$;
REVOKE ALL ON FUNCTION public.get_commercial_health_mix_v1(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_commercial_health_mix_v1(text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.sync_commercial_health_from_sheet()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE response extensions.http_response; t jsonb; p jsonb; assignments jsonb; asof date; year_value integer; current_month integer; old_timeout text;
 month_names text[]:=ARRAY['JANEIRO','FEVEREIRO','MARÇO','ABRIL','MAIO','JUNHO','JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO'];
 labels jsonb; period_months jsonb:='[]'; i integer; m integer; period_date date;
BEGIN
 IF NOT pg_try_advisory_xact_lock(17890101,851597314) THEN RETURN jsonb_build_object('status','busy'); END IF;
 BEGIN
  SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
  PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','20000');
  SELECT * INTO response FROM extensions.http_get('https://docs.google.com/spreadsheets/d/1yqz01zbqgkJt13go7TK77DkAhw2bdEldRrqWCKhpGjs/gviz/tq?tqx=out:json&headers=1&gid=851597314&tq=select%20A%2CB%2CC%2CD%2CE%2CF%2CG%2CH%2CI%2CJ%2CK%2CL%2CM%2CN%20where%20A%20%3E%200');
  IF response.status<>200 THEN RAISE EXCEPTION 'Falha ao ler Análise'; END IF;
  t:=private.commercial_health_gviz(response.content); p:=private.commercial_health_parse(t); labels:=p->'labels';
  SELECT * INTO response FROM extensions.http_get('https://docs.google.com/spreadsheets/d/1yqz01zbqgkJt13go7TK77DkAhw2bdEldRrqWCKhpGjs/gviz/tq?tqx=out:json&headers=1&gid=0&tq=select%20A%2CE%2CF%2Cmax(D)%20where%20A%20%3E%200%20group%20by%20A%2CE%2CF%20format%20max(D)%20%27yyyy-MM-dd%27');
  IF response.status<>200 THEN RAISE EXCEPTION 'Falha ao ler responsáveis e data da fonte'; END IF;
  assignments:=private.commercial_health_assignments(private.commercial_health_gviz(response.content));
  asof:=(assignments->>'asOf')::date;year_value:=extract(year FROM asof)::integer;
  p:=jsonb_set(p,'{rows}',(SELECT jsonb_agg(r||jsonb_build_object('sourceSellerCode',coalesce(assignments->'sellers'->(r->>'code')->>'sellerCode',''),'sourceSeller',coalesce(assignments->'sellers'->(r->>'code')->>'seller','Não informado'))) FROM jsonb_array_elements(p->'rows')r));
  current_month:=array_position(month_names,upper(labels->>10));
  IF current_month IS NULL THEN RAISE EXCEPTION 'Mês atual não reconhecido'; END IF;
  FOR i IN SELECT unnest(ARRAY[2,3,4,5,8,10]) LOOP
   m:=array_position(month_names,upper(labels->>i));
   IF m IS NULL THEN RAISE EXCEPTION 'Mês histórico não reconhecido'; END IF;
   period_date:=make_date(year_value-CASE WHEN m>current_month THEN 1 ELSE 0 END,m,1);
   period_months:=period_months||jsonb_build_array(to_char(period_date,'YYYY-MM'));
  END LOOP;
  p:=private.commercial_health_enrich(p||jsonb_build_object('periods',period_months,'asOf',asof));
  IF to_regprocedure('private.commercial_health_mix_refresh(jsonb)') IS NOT NULL THEN p:=private.commercial_health_mix_refresh(p); END IF;
  INSERT INTO public.commercial_health_sync(id,payload,synced_at,attempted_at,last_error) VALUES(true,p,clock_timestamp(),clock_timestamp(),null)
  ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,synced_at=excluded.synced_at,attempted_at=excluded.attempted_at,last_error=null;
  PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
  RETURN jsonb_build_object('status','synced','clients',jsonb_array_length(p->'rows'),'duplicatesMerged',p->'duplicatesMerged');
 EXCEPTION WHEN OTHERS THEN
  PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
  INSERT INTO public.commercial_health_sync(id,attempted_at,last_error) VALUES(true,clock_timestamp(),SQLERRM)
  ON CONFLICT(id) DO UPDATE SET attempted_at=excluded.attempted_at,last_error=excluded.last_error;
  RETURN jsonb_build_object('status','error','message','Última versão válida preservada');
 END;
END;$$;

CREATE OR REPLACE FUNCTION public.get_commercial_health_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE snapshot public.commercial_health_sync;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 SELECT * INTO snapshot FROM public.commercial_health_sync WHERE id=true;
 IF snapshot.payload IS NULL THEN RETURN jsonb_build_object('schema_version',1,'rows','[]'::jsonb,'syncedAt',null,'syncError',true); END IF;
 RETURN jsonb_build_object('schema_version',1,'rows',coalesce(snapshot.payload->'rows','[]'::jsonb),'periods',snapshot.payload->'periods','asOf',snapshot.payload->'asOf',
  'mixVersion',snapshot.payload->'mixVersion','syncedAt',snapshot.synced_at,'syncError',snapshot.last_error IS NOT NULL,'duplicatesMerged',snapshot.payload->'duplicatesMerged');
END;$$;
-- Backfill mix from the current validated snapshot without claiming a new Sheets read.
UPDATE public.commercial_health_sync SET payload=private.commercial_health_mix_refresh(payload) WHERE id=true AND payload IS NOT NULL;
COMMIT;
