-- Read-only Sheets source; only validated complete snapshots replace the last good data.
BEGIN;
CREATE TABLE IF NOT EXISTS public.commercial_health_sync (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),
 source_sheet_id text NOT NULL DEFAULT '1yqz01zbqgkJt13go7TK77DkAhw2bdEldRrqWCKhpGjs' CHECK(source_sheet_id='1yqz01zbqgkJt13go7TK77DkAhw2bdEldRrqWCKhpGjs'),
 payload jsonb, synced_at timestamptz, attempted_at timestamptz, last_error text
);
ALTER TABLE public.commercial_health_sync ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.commercial_health_sync FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.commercial_health_sync TO authenticated;
GRANT ALL ON public.commercial_health_sync TO service_role;
DROP POLICY IF EXISTS commercial_health_read ON public.commercial_health_sync;
CREATE POLICY commercial_health_read ON public.commercial_health_sync FOR SELECT TO authenticated USING ((SELECT public.is_approved()));

CREATE OR REPLACE FUNCTION private.commercial_health_gviz(body text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE p jsonb;
BEGIN
 IF body IS NULL OR octet_length(body)>8388608 OR position('google.visualization.Query.setResponse(' in body)=0 THEN RAISE EXCEPTION 'Resposta inválida do Sheets'; END IF;
 p:=substring(body from '\{.*\}')::jsonb;
 IF p->>'status' IS DISTINCT FROM 'ok' OR jsonb_typeof(p->'table'->'rows') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Planilha indisponível ou com erro de cálculo'; END IF;
 RETURN p->'table';
END;$$;

CREATE OR REPLACE FUNCTION private.commercial_health_parse(t jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE cells jsonb; r jsonb; code text; item jsonb; previous jsonb; items jsonb:='{}'; numbers jsonb;
 header jsonb; status text; field integer; duplicates integer:=0;
BEGIN
 SELECT jsonb_agg(c->>'label' ORDER BY idx) INTO header FROM jsonb_array_elements(t->'cols') WITH ORDINALITY x(c,idx);
 IF jsonb_array_length(header) IS DISTINCT FROM 14 OR header->>0<>'CODCLI' OR header->>1<>'CLIENTE' OR header->>6<>'MÉDIAHIST' OR header->>7<>'MEDIANAHIST' OR header->>9<>'VARIAÇÃO%' OR header->>11<>'MESESPOSIT' OR header->>12<>'RESULTADO' OR header->>13<>'EXEDENTE/MED' THEN RAISE EXCEPTION 'Cabeçalhos de Análise alterados'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(t->'rows') LOOP
  cells:=r->'c';
  IF jsonb_array_length(cells)<>14 OR jsonb_typeof(cells->0->'v') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Linha sem código válido'; END IF;
  IF (cells->0->>'v')::numeric<=0 THEN CONTINUE; END IF;
  IF (cells->0->>'v')::numeric<>trunc((cells->0->>'v')::numeric) THEN RAISE EXCEPTION 'Código de cliente inválido'; END IF;
  code:=((cells->0->>'v')::numeric)::bigint::text;
  IF coalesce(btrim(cells->1->>'v'),'')='' THEN RAISE EXCEPTION 'Cliente sem nome'; END IF;
  FOREACH field IN ARRAY ARRAY[2,3,4,5,6,7,8,10,11,13] LOOP
   IF jsonb_typeof(cells->field->'v') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Valor ausente ou inválido em Análise'; END IF;
  END LOOP;
  IF cells->9->'v' IS NOT NULL AND cells->9->'v'<>'null'::jsonb AND jsonb_typeof(cells->9->'v')<>'number' THEN RAISE EXCEPTION 'Variação inválida'; END IF;
  IF (cells->11->>'v')::numeric NOT BETWEEN 0 AND 4 OR (cells->11->>'v')::numeric<>trunc((cells->11->>'v')::numeric) THEN RAISE EXCEPTION 'Meses positivos inválidos'; END IF;
  status:=upper(btrim(cells->12->>'v'));
  IF status NOT IN ('CRÍTICO','ANALISAR','SEM ALERTA') OR status IS NULL THEN RAISE EXCEPTION 'Classificação não reconhecida'; END IF;
  item:=jsonb_build_object('code',code,'name',cells->1->>'v','history',jsonb_build_array(cells->2->'v',cells->3->'v',cells->4->'v',cells->5->'v'),
   'average',cells->6->'v','median',cells->7->'v','previous',cells->8->'v','variation',cells->9->'v','current',cells->10->'v',
   'positiveMonths',(cells->11->>'v')::numeric::integer,'status',status,'excess',cells->13->'v');
  previous:=items->code;
  IF previous IS NOT NULL THEN
   IF (previous-'name') IS DISTINCT FROM (item-'name') THEN RAISE EXCEPTION 'Código duplicado com valores conflitantes'; END IF;
   duplicates:=duplicates+1;
   IF length(previous->>'name')>length(item->>'name') THEN item:=jsonb_set(item,'{name}',previous->'name'); END IF;
  END IF;
  items:=jsonb_set(items,ARRAY[code],item);
 END LOOP;
 IF items='{}'::jsonb THEN RAISE EXCEPTION 'Análise sem clientes'; END IF;
 RETURN jsonb_build_object('schema_version',1,'labels',header,'duplicatesMerged',duplicates,'rows',(SELECT jsonb_agg(value ORDER BY key::bigint) FROM jsonb_each(items)));
END;$$;

CREATE OR REPLACE FUNCTION private.commercial_health_assignments(t jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE row_value jsonb; c jsonb; code text; seller_code text; seller_name text; parts text[]; day_value date; latest date; previous jsonb; result jsonb:='{}'; asof date;
BEGIN
 IF t->'cols'->0->>'label' IS DISTINCT FROM 'CODCLI' OR t->'cols'->1->>'label' IS DISTINCT FROM 'CODUSUR' OR t->'cols'->2->>'label' IS DISTINCT FROM 'NOME' OR t->'cols'->3->>'id' IS DISTINCT FROM 'max-D' THEN RAISE EXCEPTION 'Cabeçalhos de responsáveis alterados'; END IF;
 FOR row_value IN SELECT value FROM jsonb_array_elements(t->'rows') LOOP
  c:=row_value->'c'; parts:=regexp_match(c->3->>'v','^Date\((\d+),(\d+),(\d+)\)$');
  IF parts IS NULL THEN RAISE EXCEPTION 'Data inválida em Relatório'; END IF;
  day_value:=make_date(parts[1]::integer,parts[2]::integer+1,parts[3]::integer);asof:=greatest(asof,day_value);
  IF jsonb_typeof(c->0->'v') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Código inválido em Relatório'; END IF;
  code:=((c->0->>'v')::numeric)::bigint::text;
  IF jsonb_typeof(c->1->'v') IS DISTINCT FROM 'number' OR coalesce(btrim(c->2->>'v'),'')='' THEN CONTINUE; END IF;
  seller_code:=((c->1->>'v')::numeric)::bigint::text;seller_name:=c->2->>'v';previous:=result->code;
  IF previous IS NULL OR day_value>(previous->>'date')::date THEN
   result:=jsonb_set(result,ARRAY[code],jsonb_build_object('sellerCode',seller_code,'seller',seller_name,'date',day_value));
  ELSIF day_value=(previous->>'date')::date AND seller_code IS DISTINCT FROM previous->>'sellerCode' THEN
   result:=jsonb_set(result,ARRAY[code],jsonb_build_object('sellerCode','','seller','Não informado','date',day_value));
  END IF;
 END LOOP;
 IF asof IS NULL THEN RAISE EXCEPTION 'Relatório sem data'; END IF;
 RETURN jsonb_build_object('asOf',asof,'sellers',result);
END;$$;

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
  p:=p||jsonb_build_object('periods',period_months,'asOf',asof);
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
REVOKE ALL ON FUNCTION private.commercial_health_gviz(text),private.commercial_health_parse(jsonb),private.commercial_health_assignments(jsonb),private.sync_commercial_health_from_sheet() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_commercial_health_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE snapshot public.commercial_health_sync; enriched jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 SELECT * INTO snapshot FROM public.commercial_health_sync WHERE id=true;
 IF snapshot.payload IS NULL THEN RETURN jsonb_build_object('schema_version',1,'rows','[]'::jsonb,'syncedAt',null,'syncError',true); END IF;
 WITH clients AS MATERIALIZED (
  SELECT DISTINCT ON(codigo_cliente) codigo_cliente,rca1,codsupervisor,nomecliente FROM public.data_clients ORDER BY codigo_cliente,created_at DESC NULLS LAST
 ), seller_supervisor AS MATERIALIZED (
  SELECT DISTINCT ON(codusur) codusur,codsupervisor FROM public.data_summary_frequency
  WHERE coalesce(codusur,'')<>'' AND coalesce(codsupervisor,'')<>''
  ORDER BY codusur,ano DESC,mes DESC,codsupervisor
 ), client_rows AS (
  SELECT r,coalesce(nullif(c.rca1,''),r->>'sourceSellerCode','') rca1,c.codsupervisor,coalesce(nullif(c.nomecliente,''),r->>'name') name
  FROM jsonb_array_elements(snapshot.payload->'rows') r
  LEFT JOIN clients c ON c.codigo_cliente=r->>'code'
 )
 SELECT jsonb_agg(r||jsonb_build_object('name',name,'sellerCode',coalesce(rca1,''),'seller',coalesce(nullif(v.nome,''),CASE WHEN rca1=r->>'sourceSellerCode' THEN nullif(r->>'sourceSeller','') END,nullif(rca1,''),'Não informado'),
  'supervisorCode',coalesce(nullif(c.codsupervisor,''),ss.codsupervisor,''),'supervisor',coalesce(nullif(ds.nome,''),nullif(c.codsupervisor,''),ss.codsupervisor,'Não informado')) ORDER BY r->>'code') INTO enriched
 FROM client_rows c LEFT JOIN public.dim_vendedores v ON v.codigo=c.rca1
 LEFT JOIN seller_supervisor ss ON ss.codusur=c.rca1
 LEFT JOIN public.dim_supervisores ds ON ds.codigo=coalesce(nullif(c.codsupervisor,''),ss.codsupervisor);
 RETURN jsonb_build_object('schema_version',1,'rows',coalesce(enriched,'[]'::jsonb),'periods',snapshot.payload->'periods','asOf',snapshot.payload->'asOf',
  'syncedAt',snapshot.synced_at,'syncError',snapshot.last_error IS NOT NULL,'duplicatesMerged',snapshot.payload->'duplicatesMerged');
END;$$;
REVOKE ALL ON FUNCTION public.get_commercial_health_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_commercial_health_v1() TO authenticated;
COMMIT;
-- Activate only after initial sync and API checks succeed:
-- SELECT cron.schedule('sync-commercial-health','0 */12 * * *','select private.sync_commercial_health_from_sheet();');
