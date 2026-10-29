-- Planejamento: Farol owns portfolio/routes; Evolution owns product and sales evidence.
BEGIN;
CREATE TABLE IF NOT EXISTS public.planning_snapshot (
 id boolean PRIMARY KEY DEFAULT true CHECK(id), version uuid, meta jsonb, synced_at timestamptz,
 attempted_at timestamptz, last_error text
);
CREATE TABLE IF NOT EXISTS public.planning_clients (
 code text PRIMARY KEY, version uuid NOT NULL, supervisor_code text NOT NULL, seller_code text NOT NULL,
 summary jsonb NOT NULL, detail jsonb NOT NULL
);
ALTER TABLE public.planning_snapshot ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planning_clients ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.planning_snapshot,public.planning_clients FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.planning_snapshot,public.planning_clients TO authenticated;
DROP POLICY IF EXISTS planning_snapshot_read ON public.planning_snapshot;
CREATE POLICY planning_snapshot_read ON public.planning_snapshot FOR SELECT TO authenticated USING ((SELECT public.is_approved()));
DROP POLICY IF EXISTS planning_clients_read ON public.planning_clients;
CREATE POLICY planning_clients_read ON public.planning_clients FOR SELECT TO authenticated USING ((SELECT public.is_approved()));

-- CSV export includes filtered-out rows. Gviz applies the editor's active sheet filter.
CREATE OR REPLACE FUNCTION private.planning_csv_fetch(gid text,selected_columns integer[],header_row integer,is_calendar boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE response extensions.http_response; token text[]; fields text[]:='{}'; cells jsonb; cols jsonb:='[]'; rows jsonb:='[]';
 row_num integer:=0; consumed integer:=0; field_value text; i integer; parts text[];
BEGIN
 SELECT * INTO response FROM extensions.http_get('https://docs.google.com/spreadsheets/d/1YAAb2oJNltN1AvhHeCsp0jEkbGr8lvjSqq5GAkJLJyg/export?format=csv&gid='||gid);
 IF response.status<>200 OR octet_length(response.content)>8388608 OR left(response.content,1)='<' THEN RAISE EXCEPTION 'CSV do Farol indisponível'; END IF;
 FOR token IN SELECT regexp_matches(response.content,'("(?:[^"]|"")*"|[^,"\r\n]*)(,|\r?\n|$)','g') LOOP
  consumed:=consumed+length(token[1])+length(token[2]);
  field_value:=token[1];
  IF left(field_value,1)='"' THEN field_value:=replace(substr(field_value,2,length(field_value)-2),'""','"'); END IF;
  fields:=array_append(fields,field_value);
  IF token[2]=',' THEN CONTINUE; END IF;
  row_num:=row_num+1;
  IF row_num=header_row THEN
   FOREACH i IN ARRAY selected_columns LOOP cols:=cols||jsonb_build_array(jsonb_build_object('label',fields[i])); END LOOP;
  ELSIF row_num>header_row AND coalesce(fields[selected_columns[1]],'')<>'' THEN
   cells:='[]';
   FOREACH i IN ARRAY selected_columns LOOP
    field_value:=fields[i];
    IF is_calendar AND i=1 THEN
     parts:=regexp_match(field_value,'^([0-9]{2})/([0-9]{2})/([0-9]{4})$');
     IF parts IS NULL THEN RAISE EXCEPTION 'Data inválida no calendário'; END IF;
     field_value:='Date('||parts[3]||','||(parts[2]::integer-1)||','||parts[1]::integer||')';
    END IF;
    cells:=cells||jsonb_build_array(jsonb_build_object('v',field_value));
   END LOOP;
   rows:=rows||jsonb_build_array(jsonb_build_object('c',cells));
  END IF;
  fields:='{}';
 END LOOP;
 IF consumed<>length(response.content) OR jsonb_array_length(rows)=0 THEN RAISE EXCEPTION 'CSV incompleto ou inválido'; END IF;
 RETURN jsonb_build_object('cols',cols,'rows',rows);
END;$$;
REVOKE ALL ON FUNCTION private.planning_csv_fetch(text,integer[],integer,boolean) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.planning_sync()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE c jsonb; routes jsonb; cal jsonb; cells jsonb; cell_row jsonb; parts text[]; dt date;
 m date:=date_trunc('month',now() AT TIME ZONE 'America/Bahia')::date;
 today date:=(now() AT TIME ZONE 'America/Bahia')::date;
 generation uuid:=gen_random_uuid(); complete boolean; cutoff date; old_timeout text; n integer;
BEGIN
 IF NOT pg_try_advisory_xact_lock(17890101,415990480) THEN RETURN jsonb_build_object('status','busy'); END IF;
 BEGIN
 SELECT value INTO old_timeout FROM extensions.http_list_curlopt() WHERE curlopt='CURLOPT_TIMEOUT_MS';
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','20000');
 c:=private.planning_csv_fetch('376419352',ARRAY[1,2,3,5,6,10,16,17,19],2);
 routes:=private.planning_csv_fetch('415990480',ARRAY[1,2,3,10,13],0);
 cal:=private.planning_csv_fetch('988715689',ARRAY[1,2,3],1,true);
 IF c->'cols'->0->>'label' IS DISTINCT FROM 'Código' OR c->'cols'->3->>'label' IS DISTINCT FROM 'RCA 1'
 OR c->'cols'->6->>'label' IS DISTINCT FROM 'Dia de Atendimento' OR c->'cols'->7->>'label' IS DISTINCT FROM 'Freq de Atendimento'
 OR cal->'cols'->0->>'label' IS DISTINCT FROM 'DATA' OR cal->'cols'->1->>'label' IS DISTINCT FROM 'FREQ'
 OR jsonb_array_length(c->'cols')<>9 THEN RAISE EXCEPTION 'Estrutura do Farol alterada'; END IF;
 CREATE TEMP TABLE pl_portfolio(code text,name text,seller text,seller_name text,city text,day text,freq text) ON COMMIT DROP;
 FOR cell_row IN SELECT value FROM jsonb_array_elements(c->'rows') LOOP
  cells:=cell_row->'c';
  IF upper(btrim(cells->8->>'v'))<>'ATIVO' THEN CONTINUE; END IF;
  IF coalesce(cells->0->>'v','')!~'^[0-9]+([.]0+)?$' OR coalesce(cells->3->>'v','')!~'^[0-9]+([.]0+)?$'
   OR coalesce(btrim(cells->1->>'v'),'')='' THEN RAISE EXCEPTION 'Cliente ativo inválido no Farol'; END IF;
  -- Counter sales have no field portfolio or visit plan.
  IF (cells->3->>'v')::numeric=53 THEN CONTINUE; END IF;
  INSERT INTO pl_portfolio VALUES(((cells->0->>'v')::numeric)::bigint::text,coalesce(nullif(cells->2->>'v',''),cells->1->>'v'),
   CASE WHEN (cells->3->>'v')::numeric=267 THEN '321' ELSE ((cells->3->>'v')::numeric)::bigint::text END,cells->4->>'v',cells->5->>'v',cells->6->>'v',cells->7->>'v');
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pl_portfolio) OR EXISTS(SELECT 1 FROM pl_portfolio GROUP BY code HAVING count(DISTINCT seller)>1) THEN RAISE EXCEPTION 'Carteira vazia ou responsáveis conflitantes'; END IF;
 CREATE TEMP TABLE pl_routes ON COMMIT DROP AS
 SELECT DISTINCT ((r->'c'->2->>'v')::numeric)::bigint::text code,CASE WHEN (r->'c'->1->>'v')::numeric=267 THEN '321' ELSE ((r->'c'->1->>'v')::numeric)::bigint::text END seller,
 CASE WHEN (r->'c'->1->>'v')::numeric=267 THEN '21' ELSE ((r->'c'->0->>'v')::numeric)::bigint::text END supervisor,
 r->'c'->3->>'v' AS day,r->'c'->4->>'v' freq FROM jsonb_array_elements(routes->'rows')r;
 IF EXISTS(SELECT 1 FROM pl_routes GROUP BY code,seller HAVING count(DISTINCT supervisor)>1) THEN RAISE EXCEPTION 'Supervisor conflitante em ROTA'; END IF;
 CREATE TEMP TABLE pl_calendar(day_date date PRIMARY KEY,freq text,day text) ON COMMIT DROP;
 FOR cell_row IN SELECT value FROM jsonb_array_elements(cal->'rows') LOOP
  cells:=cell_row->'c';parts:=regexp_match(cells->0->>'v','^Date\(([0-9]+),([0-9]+),([0-9]+)\)$');
  IF parts IS NULL THEN RAISE EXCEPTION 'Calendário inválido'; END IF;
  dt:=make_date(parts[1]::integer,parts[2]::integer+1,parts[3]::integer);
  IF dt>=m-1 AND dt<m+interval '1 month' THEN INSERT INTO pl_calendar VALUES(dt,cells->1->>'v',cells->2->>'v'); END IF;
 END LOOP;
 IF (SELECT count(*) FROM pl_calendar WHERE day_date>=m)<>extract(day FROM m+interval '1 month'-interval '1 day') THEN RAISE EXCEPTION 'Calendário do mês incompleto'; END IF;
 CREATE TEMP TABLE pl_people ON COMMIT DROP AS
 WITH p AS(SELECT DISTINCT ON(code) * FROM pl_portfolio ORDER BY code,name),
 d AS(SELECT DISTINCT ON(codigo_cliente) * FROM public.data_clients ORDER BY codigo_cliente,created_at DESC,id),
 old AS(SELECT value r FROM public.commercial_health_sync,jsonb_array_elements(payload->'rows') WHERE id=true)
 SELECT p.*,coalesce(nullif(d.ramo_atividade,''),nullif(d.ramo,''),'Não informado') segment,
 coalesce(nullif((SELECT min(supervisor) FROM pl_routes WHERE code=p.code AND seller=p.seller),''),
 nullif(d.codsupervisor,''),nullif(old.r->>'supervisorCode',''),'unknown') supervisor,
 coalesce(v.nome,p.seller_name,'Não informado') seller_label
 FROM p LEFT JOIN d ON d.codigo_cliente=p.code LEFT JOIN public.dim_vendedores v ON v.codigo=p.seller
 LEFT JOIN old ON old.r->>'code'=p.code;
 CREATE UNIQUE INDEX ON pl_people(code);
 -- Each month has one authoritative source. No union of overlapping history/current months.
 CREATE TEMP TABLE pl_sales ON COMMIT DROP AS
 SELECT s.*,CASE WHEN codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family
 FROM (
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_history
 WHERE dtped>=(m-interval '3 months') AT TIME ZONE 'UTC' AND dtped<m::timestamp AT TIME ZONE 'UTC'
 UNION ALL
 SELECT codcli,produto,codfor,dtped,tipovenda,vlvenda,qtvenda FROM public.data_detailed
 WHERE dtped>=m::timestamp AT TIME ZONE 'UTC' AND dtped<(today+1)::timestamp AT TIME ZONE 'UTC'
 )s WHERE codfor IN('707','708','752','1119') AND tipovenda IN('1','9');
 SELECT max(dtped AT TIME ZONE 'UTC')::date INTO cutoff FROM pl_sales WHERE dtped>=m::timestamp AT TIME ZONE 'UTC';
 SELECT count(DISTINCT date_trunc('month',dtped AT TIME ZONE 'UTC'))=3 INTO complete FROM pl_sales WHERE dtped<m::timestamp AT TIME ZONE 'UTC';
 CREATE INDEX ON pl_sales(codcli,produto);
 CREATE TEMP TABLE pl_skus ON COMMIT DROP AS
 SELECT codcli,produto,max(family) family,
 count(DISTINCT date_trunc('month',dtped AT TIME ZONE 'UTC')) FILTER(WHERE dtped<m::timestamp AT TIME ZONE 'UTC') months,
 sum(vlvenda) FILTER(WHERE dtped<m::timestamp AT TIME ZONE 'UTC')/3 historical_value,
 sum(qtvenda) FILTER(WHERE dtped<m::timestamp AT TIME ZONE 'UTC')/3 historical_qty,
 count(*) FILTER(WHERE dtped>=m::timestamp AT TIME ZONE 'UTC')>0 current,
 coalesce(sum(vlvenda) FILTER(WHERE dtped>=m::timestamp AT TIME ZONE 'UTC'),0) current_value,
 max(dtped AT TIME ZONE 'UTC')::date last_purchase
 FROM pl_sales WHERE vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL GROUP BY codcli,produto;
 CREATE INDEX ON pl_skus(codcli);
 -- Peer support counts unique clients, not transaction lines. Never infer a segment from a name.
 CREATE TEMP TABLE pl_peer ON COMMIT DROP AS
 SELECT p.segment,s.produto,count(DISTINCT s.codcli) buyers,
 max(sz.peers) peers
 FROM pl_skus s JOIN pl_people p ON p.code=s.codcli
 JOIN (SELECT q.segment,count(DISTINCT t.codcli) peers FROM pl_skus t JOIN pl_people q ON q.code=t.codcli WHERE t.months>0 GROUP BY q.segment) sz ON sz.segment=p.segment
 WHERE s.months>0 AND p.segment<>'Não informado' GROUP BY p.segment,s.produto;
 CREATE INDEX ON pl_peer(segment);
 CREATE TEMP TABLE pl_stats ON COMMIT DROP AS
 SELECT p.code,
 coalesce(sum(s.vlvenda) FILTER(WHERE s.dtped<m::timestamp AT TIME ZONE 'UTC'),0)/3 average_value,
 coalesce(sum(s.vlvenda) FILTER(WHERE s.dtped>=m::timestamp AT TIME ZONE 'UTC'),0) current_value,
 max(s.dtped AT TIME ZONE 'UTC')::date last_purchase
 FROM pl_people p LEFT JOIN pl_sales s ON s.codcli=p.code GROUP BY p.code;
 CREATE TEMP TABLE pl_mix ON COMMIT DROP AS
 SELECT p.code,coalesce(sum(s.months),0)::numeric/3 average_mix,
 coalesce(sum(s.months) FILTER(WHERE s.family='SALTY'),0)::numeric/3 average_salty,
 coalesce(sum(s.months) FILTER(WHERE s.family='FOODS'),0)::numeric/3 average_foods,
 count(*) FILTER(WHERE s.current) current_mix,count(*) FILTER(WHERE s.current AND s.family='SALTY') current_salty,
 count(*) FILTER(WHERE s.current AND s.family='FOODS') current_foods,
 count(*) FILTER(WHERE s.months>0 AND NOT s.current) missing
 FROM pl_people p LEFT JOIN pl_skus s ON s.codcli=p.code GROUP BY p.code;
 DELETE FROM public.planning_clients WHERE code IS NOT NULL;
 INSERT INTO public.planning_clients(code,version,supervisor_code,seller_code,summary,detail)
 SELECT p.code,generation,p.supervisor,p.seller,
 jsonb_build_object('code',p.code,'name',p.name,'city',p.city,'segment',p.segment,'sellerCode',p.seller,'seller',p.seller_label,
 'supervisorCode',p.supervisor,'supervisor',coalesce(d.nome,'Não informado'),'averageValue',CASE WHEN complete THEN st.average_value END,
 'currentValue',st.current_value,'averageMix',CASE WHEN complete THEN mx.average_mix END,'averageSalty',CASE WHEN complete THEN mx.average_salty END,
 'averageFoods',CASE WHEN complete THEN mx.average_foods END,'currentMix',mx.current_mix,'currentSalty',mx.current_salty,'currentFoods',mx.current_foods,
 'missing',mx.missing,'lastPurchase',st.last_purchase,'routes',rr.routes,'visitDates',rr.dates),
 jsonb_build_object('skus',ss.skus,'suggestions',ns.skus)
 FROM pl_people p JOIN pl_stats st ON st.code=p.code JOIN pl_mix mx ON mx.code=p.code
 LEFT JOIN public.dim_supervisores d ON d.codigo=p.supervisor
 CROSS JOIN LATERAL(
 SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('day',r.day,'frequency',r.freq)),'[]') routes,
 coalesce(jsonb_agg(DISTINCT to_char(k.day_date,'YYYY-MM-DD')) FILTER(WHERE k.day_date IS NOT NULL),'[]') dates
 FROM(SELECT day,freq FROM pl_routes WHERE code=p.code AND seller=p.seller
 UNION SELECT p.day,p.freq WHERE NOT EXISTS(SELECT 1 FROM pl_routes WHERE code=p.code AND seller=p.seller))r
 LEFT JOIN pl_calendar k ON k.day=r.day AND (r.freq='SEMANAL' OR r.freq=k.freq)
 )rr
 CROSS JOIN LATERAL(
 SELECT coalesce(jsonb_agg(jsonb_build_object('code',s.produto,'name',coalesce(pr.descricao,s.produto),'family',s.family,'months',s.months,
 'averageValue',s.historical_value,'averageQuantity',s.historical_qty,'current',s.current,'currentValue',s.current_value,'lastPurchase',s.last_purchase)
 ORDER BY s.months DESC,s.historical_value DESC NULLS LAST,s.produto),'[]') skus
 FROM pl_skus s LEFT JOIN public.dim_produtos pr ON pr.codigo=s.produto WHERE s.codcli=p.code
 )ss
 CROSS JOIN LATERAL(
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.buyers DESC,x.code),'[]') skus FROM(
 SELECT pe.produto code,pr.descricao name,CASE WHEN pr.codfor IN('707','708','752') THEN 'SALTY' ELSE 'FOODS' END family,
 pe.buyers,pe.peers,round(pe.buyers::numeric/nullif(pe.peers,0)*100,1) penetration
 FROM pl_peer pe JOIN public.dim_produtos pr ON pr.codigo=pe.produto
 WHERE complete AND pe.segment=p.segment AND pe.buyers>=3 AND pe.peers>=5
 AND NOT EXISTS(SELECT 1 FROM pl_skus s WHERE s.codcli=p.code AND s.produto=pe.produto)
 AND EXISTS(SELECT 1 FROM pl_skus s WHERE s.produto=pe.produto AND s.current)
 ORDER BY pe.buyers DESC,pe.produto LIMIT 8)x
 )ns;
 GET DIAGNOSTICS n=ROW_COUNT;
 INSERT INTO public.planning_snapshot(id,version,meta,synced_at,attempted_at,last_error)
 VALUES(true,generation,jsonb_build_object('month',to_char(m,'YYYY-MM'),'historyStart',to_char(m-interval '3 months','YYYY-MM'),
 'historyEnd',to_char(m-interval '1 month','YYYY-MM'),'historyComplete',complete,'salesThrough',cutoff,'clients',n,
 'sourceSheetId','1YAAb2oJNltN1AvhHeCsp0jEkbGr8lvjSqq5GAkJLJyg','routeDates',(SELECT jsonb_agg(to_char(day_date,'YYYY-MM-DD') ORDER BY day_date) FROM pl_calendar)),clock_timestamp(),clock_timestamp(),null)
 ON CONFLICT(id) DO UPDATE SET version=excluded.version,meta=excluded.meta,synced_at=excluded.synced_at,attempted_at=excluded.attempted_at,last_error=null;
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
 RETURN jsonb_build_object('status','synced','clients',n,'version',generation);
 EXCEPTION WHEN OTHERS THEN
 PERFORM extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS',coalesce(old_timeout,'5000'));
 INSERT INTO public.planning_snapshot(id,attempted_at,last_error) VALUES(true,clock_timestamp(),SQLERRM)
 ON CONFLICT(id) DO UPDATE SET attempted_at=excluded.attempted_at,last_error=excluded.last_error;
 RETURN jsonb_build_object('status','error','message',SQLERRM);
 END;
END;$$;
REVOKE ALL ON FUNCTION private.planning_sync() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_planning_v1(p_supervisor text DEFAULT NULL,p_seller text DEFAULT NULL,p_visit_date text DEFAULT NULL,p_search text DEFAULT '',p_offset integer DEFAULT 0,p_limit integer DEFAULT 24)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE snapshot public.planning_snapshot; result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 SELECT * INTO snapshot FROM public.planning_snapshot WHERE id=true;
 IF snapshot.version IS NULL THEN RAISE EXCEPTION 'Planejamento aguardando primeira sincronização'; END IF;
 WITH filtered AS MATERIALIZED(
 SELECT summary r FROM public.planning_clients WHERE version=snapshot.version
 AND (p_supervisor IS NULL OR supervisor_code=p_supervisor) AND(p_seller IS NULL OR seller_code=p_seller)
 AND(p_visit_date IS NULL OR summary->'visitDates' ? p_visit_date)
 AND(coalesce(p_search,'')='' OR position(lower(p_search) in lower(summary->>'code'||' '||(summary->>'name')||' '||(summary->>'city')))>0)
 ), page AS(SELECT r FROM filtered ORDER BY (r->>'missing')::integer DESC,r->>'name',r->>'code' OFFSET greatest(p_offset,0) LIMIT least(greatest(p_limit,1),100))
 SELECT jsonb_build_object('rows',coalesce((SELECT jsonb_agg(r) FROM page),'[]'),'total',count(*),
 'kpis',jsonb_build_object('noSale',count(*) FILTER(WHERE (r->>'currentMix')::integer=0),'missing',coalesce(sum((r->>'missing')::integer),0),
 'currentValue',coalesce(sum((r->>'currentValue')::numeric),0))) INTO result FROM filtered;
 RETURN result||snapshot.meta||jsonb_build_object('version',snapshot.version,'syncedAt',snapshot.synced_at,'syncError',snapshot.last_error IS NOT NULL,
 'supervisors',(SELECT coalesce(jsonb_agg(x ORDER BY x->>'name'),'[]') FROM(SELECT DISTINCT jsonb_build_object('code',supervisor_code,'name',summary->>'supervisor')x FROM public.planning_clients WHERE version=snapshot.version)t),
 'sellers',(SELECT coalesce(jsonb_agg(x ORDER BY x->>'name'),'[]') FROM(SELECT DISTINCT jsonb_build_object('code',seller_code,'name',summary->>'seller')x FROM public.planning_clients WHERE version=snapshot.version AND(p_supervisor IS NULL OR supervisor_code=p_supervisor))t));
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_v1(text,text,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_v1(text,text,text,text,integer,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_planning_client_v1(p_code text,p_version uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_approved() THEN RAISE EXCEPTION 'Acesso não autorizado' USING ERRCODE='42501'; END IF;
 SELECT c.summary||c.detail||s.meta||jsonb_build_object('version',s.version,'syncedAt',s.synced_at,'syncError',s.last_error IS NOT NULL)
 INTO result FROM public.planning_clients c JOIN public.planning_snapshot s ON s.version=c.version AND s.id=true
 WHERE c.code=p_code AND c.version=p_version;
 IF result IS NULL THEN RAISE EXCEPTION 'Planejamento atualizado. Atualize a lista e tente novamente.'; END IF;
 RETURN result;
END;$$;
REVOKE ALL ON FUNCTION public.get_planning_client_v1(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_planning_client_v1(text,uuid) TO authenticated;
COMMIT;

-- Runs entirely in Supabase; page refreshes only read the prepared snapshot.
SELECT cron.schedule('sync-planning-farol','10 * * * *','select private.planning_sync();');
