BEGIN;
DO $$
DECLARE mismatch integer;
BEGIN
 IF has_function_privilege('anon','public.get_planning_v1(text,text,text,text,integer,integer)','EXECUTE')
 OR has_function_privilege('authenticated','private.planning_sync()','EXECUTE')
 OR has_table_privilege('authenticated','public.planning_clients','UPDATE') THEN RAISE EXCEPTION 'Planning privileges too broad'; END IF;
 IF EXISTS(SELECT 1 FROM public.planning_clients c CROSS JOIN public.planning_snapshot s WHERE s.id=true AND c.version<>s.version) THEN RAISE EXCEPTION 'Mixed versions'; END IF;
 IF EXISTS(SELECT 1 FROM public.planning_clients WHERE seller_code='267') THEN RAISE EXCEPTION 'Former seller not transferred'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.planning_clients WHERE code='27') THEN RAISE EXCEPTION 'Active sheet filter leaked into imported portfolio'; END IF;
 IF EXISTS(SELECT 1 FROM public.planning_clients c CROSS JOIN LATERAL jsonb_array_elements(c.detail->'suggestions')s
 WHERE (s->>'buyers')::integer<3 OR (s->>'peers')::integer<5 OR (s->>'buyers')::integer>(s->>'peers')::integer
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(c.detail->'skus')k WHERE k->>'code'=s->>'code')) THEN RAISE EXCEPTION 'Unsubstantiated or previously purchased suggestion'; END IF;
 WITH sales AS (
 SELECT codcli,produto,codfor,vlvenda,qtvenda,date_trunc('month',dtped AT TIME ZONE 'UTC') mon FROM public.data_history
 WHERE dtped>=date_trunc('month',now() AT TIME ZONE 'America/Bahia') AT TIME ZONE 'UTC'-interval '3 months'
 AND dtped<date_trunc('month',now() AT TIME ZONE 'America/Bahia') AT TIME ZONE 'UTC'
 AND codfor IN('707','708','752','1119') AND tipovenda IN('1','9')
 ), expected AS(
 SELECT codcli,sum(vlvenda)/3 revenue FROM sales GROUP BY codcli
 ), mix AS(
 SELECT codcli,count(DISTINCT (produto,mon))::numeric/3 total,
 count(DISTINCT (produto,mon)) FILTER(WHERE codfor IN('707','708','752'))::numeric/3 salty,
 count(DISTINCT (produto,mon)) FILTER(WHERE codfor='1119')::numeric/3 foods
 FROM sales WHERE vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL GROUP BY codcli
 )
 SELECT count(*) INTO mismatch FROM public.planning_clients c LEFT JOIN expected e ON e.codcli=c.code LEFT JOIN mix x ON x.codcli=c.code
 WHERE abs((c.summary->>'averageValue')::numeric-coalesce(e.revenue,0))>0.00001
 OR abs((c.summary->>'averageMix')::numeric-coalesce(x.total,0))>0.00001
 OR abs((c.summary->>'averageSalty')::numeric-coalesce(x.salty,0))>0.00001
 OR abs((c.summary->>'averageFoods')::numeric-coalesce(x.foods,0))>0.00001;
 IF mismatch<>0 THEN RAISE EXCEPTION 'Independent historical reconciliation failed: %',mismatch; END IF;
 WITH expected AS(
 SELECT codcli,sum(vlvenda) revenue,count(DISTINCT produto) FILTER(WHERE vlvenda>0 AND qtvenda>0 AND nullif(btrim(produto),'') IS NOT NULL) mix
 FROM public.data_detailed WHERE codfor IN('707','708','752','1119') AND tipovenda IN('1','9')
 AND dtped>=date_trunc('month',now() AT TIME ZONE 'America/Bahia') AT TIME ZONE 'UTC'
 AND dtped<((now() AT TIME ZONE 'America/Bahia')::date+1)::timestamp AT TIME ZONE 'UTC' GROUP BY codcli)
 SELECT count(*) INTO mismatch FROM public.planning_clients c LEFT JOIN expected e ON e.codcli=c.code
 WHERE abs((c.summary->>'currentValue')::numeric-coalesce(e.revenue,0))>0.00001 OR (c.summary->>'currentMix')::integer<>coalesce(e.mix,0);
 IF mismatch<>0 THEN RAISE EXCEPTION 'Independent current-month reconciliation failed: %',mismatch; END IF;
 IF EXISTS(SELECT 1 FROM public.planning_clients c WHERE (c.summary->>'missing')::integer<>(SELECT count(*) FROM jsonb_array_elements(c.detail->'skus')s WHERE (s->>'months')::integer>0 AND NOT(s->>'current')::boolean)) THEN RAISE EXCEPTION 'Recovery SKU counts disagree'; END IF;
END;$$;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' AND role='user' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
-- This block exercises every supervisor/seller/day combination; individual readers are timed separately.
SET LOCAL statement_timeout='15s';
DO $$
DECLARE s record; v record; day_value text; d jsonb; n integer; a numeric; selected jsonb; seen text[]:='{}'; row_value jsonb;
BEGIN
 FOR s IN SELECT DISTINCT supervisor_code code FROM public.planning_clients LOOP
  d:=public.get_planning_v1(s.code);
  SELECT count(*),sum((summary->>'currentValue')::numeric) INTO n,a FROM public.planning_clients WHERE supervisor_code=s.code;
  IF (d->>'total')::integer<>n OR (d->'kpis'->>'currentValue')::numeric<>a THEN RAISE EXCEPTION 'Supervisor totals disagree'; END IF;
  FOR v IN SELECT DISTINCT seller_code code FROM public.planning_clients WHERE supervisor_code=s.code LOOP
   d:=public.get_planning_v1(s.code,v.code);
   SELECT count(*) INTO n FROM public.planning_clients WHERE supervisor_code=s.code AND seller_code=v.code;
   IF (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Seller count disagrees'; END IF;
   FOR day_value IN SELECT jsonb_array_elements_text(d->'routeDates') LOOP
    d:=public.get_planning_v1(s.code,v.code,day_value);
    SELECT count(*) INTO n FROM public.planning_clients WHERE supervisor_code=s.code AND seller_code=v.code AND summary->'visitDates' ? day_value;
    IF (d->>'total')::integer<>n THEN RAISE EXCEPTION 'Visit-day filter disagrees'; END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 d:=public.get_planning_v1(null,null,null,'SUPERMERCADO');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'rows')r WHERE position('supermercado' in lower(r->>'name'||' '||(r->>'city')))=0) THEN RAISE EXCEPTION 'Search mismatch'; END IF;
 d:=public.get_planning_v1(null,null,null,'',0,24);selected:=d->'rows'->0;
 IF public.get_planning_client_v1(selected->>'code',(d->>'version')::uuid)->>'name' IS DISTINCT FROM selected->>'name' THEN RAISE EXCEPTION 'Client detail mismatch'; END IF;
 FOR row_value IN SELECT value FROM jsonb_array_elements(d->'rows') LOOP seen:=array_append(seen,row_value->>'code'); END LOOP;
 d:=public.get_planning_v1(null,null,null,'',24,24);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(d->'rows')r WHERE r->>'code'=ANY(seen)) THEN RAISE EXCEPTION 'Duplicate pagination'; END IF;
 BEGIN
 PERFORM public.get_planning_client_v1(selected->>'code','00000000-0000-0000-0000-000000000000');
 RAISE EXCEPTION 'Stale detail accepted' USING ERRCODE='22000';
 EXCEPTION WHEN raise_exception THEN NULL;END;
END;$$;
ROLLBACK;
