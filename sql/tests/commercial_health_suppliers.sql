BEGIN;
SET LOCAL request.jwt.claims='{"sub":"c22e17d7-7bf8-4471-9c47-505fd961c79c","role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $test$ DECLARE old jsonb; current_all jsonb; a jsonb; b jsonb; detail jsonb; BEGIN
old:=public.get_commercial_health_month_v1('2026-10');current_all:=public.get_commercial_health_month_v2('2026-10','all');
IF old-'calculatedAt' IS DISTINCT FROM current_all-'calculatedAt'-'supplier' THEN RAISE EXCEPTION 'All supplier parity failed';END IF;
a:=public.get_commercial_health_month_v2('2026-10','salty');b:=public.get_commercial_health_month_v2('2026-10','foods');
IF a->>'supplier'<>'salty' OR b->>'supplier'<>'foods' THEN RAISE EXCEPTION 'Supplier missing';END IF;
IF EXISTS(SELECT 1 FROM jsonb_array_elements(current_all->'rows')x LEFT JOIN jsonb_array_elements(a->'rows')s ON s->>'code'=x->>'code' LEFT JOIN jsonb_array_elements(b->'rows')f ON f->>'code'=x->>'code'
WHERE abs((x->>'previous')::numeric-coalesce((s->>'previous')::numeric,0)-coalesce((f->>'previous')::numeric,0))>.001
OR abs((x->>'current')::numeric-coalesce((s->>'current')::numeric,0)-coalesce((f->>'current')::numeric,0))>.001
OR abs((x->>'mixHistorical')::numeric-coalesce((s->>'mixHistorical')::numeric,0)-coalesce((f->>'mixHistorical')::numeric,0))>.001)THEN RAISE EXCEPTION 'Supplier partition failed';END IF;
detail:=public.get_commercial_health_mix_month_v2(a#>>'{rows,0,code}','2026-10',NULL,'salty');
IF EXISTS(SELECT 1 FROM jsonb_array_elements(detail->'skus')k JOIN public.dim_produtos p ON p.codigo=k->>'code' WHERE ltrim(p.codfor,'0')NOT IN('707','708','752'))THEN RAISE EXCEPTION 'Other supplier SKU leaked';END IF;
END $test$;
SELECT 'supplier partition, all parity, scoped detail verified' status;

RESET ROLE;

CREATE TEMP TABLE health_fixture_raw(sale_date date,month_date date,codcli text,codusur text,codsupervisor text,codfor text,tipovenda text,vlvenda numeric,qtvenda numeric,produto text,source_timestamp timestamptz) ON COMMIT DROP;
INSERT INTO health_fixture_raw
SELECT d::date,d::date,'77777777','321','21',s.codfor,'1',100,1,s.produto,d::timestamp AT TIME ZONE 'UTC'
FROM generate_series('2026-05-01'::date,'2026-08-01'::date,'1 month')d CROSS JOIN(VALUES('707','salty1'),('1119','foods1'))s(codfor,produto);
INSERT INTO health_fixture_raw VALUES('2026-09-01','2026-09-01','77777777','321','21','707','1',500,1,'salty1','2026-09-01T00:00:00Z'),('2026-10-01','2026-10-01','88888888','321','21','707','1',1,1,'salty1','2026-10-01T00:00:00Z');
INSERT INTO health_fixture_raw SELECT '2026-09-01','2026-09-01','77777777','321','21','1119','1',50,1,'foods'||i,'2026-09-01T00:00:00Z' FROM generate_series(1,10)i;
GRANT SELECT ON health_fixture_raw TO authenticated;

DO $fixture$ DECLARE d text;BEGIN
SELECT pg_get_functiondef('private.commercial_health_month_read_v2(text,text)'::regprocedure) INTO d;
EXECUTE replace(d,'private.commercial_health_sales_source_v1','pg_temp.health_fixture_raw');
END $fixture$;

SET LOCAL request.jwt.claims='{"sub":"c22e17d7-7bf8-4471-9c47-505fd961c79c","role":"authenticated"}';
SET LOCAL ROLE authenticated;
DO $$ DECLARE a jsonb;s jsonb;f jsonb;BEGIN
SELECT x INTO a FROM jsonb_array_elements(public.get_commercial_health_month_v2('2026-10','all')->'rows')x WHERE x->>'code'='77777777';
SELECT x INTO s FROM jsonb_array_elements(public.get_commercial_health_month_v2('2026-10','salty')->'rows')x WHERE x->>'code'='77777777';
SELECT x INTO f FROM jsonb_array_elements(public.get_commercial_health_month_v2('2026-10','foods')->'rows')x WHERE x->>'code'='77777777';
IF a->>'status' IS DISTINCT FROM 'ANALISAR' OR s->>'status' IS DISTINCT FROM 'CRÍTICO' OR f->>'status' IS DISTINCT FROM 'ANALISAR' THEN RAISE EXCEPTION 'Cross-supplier classification leak: all %, salty %, foods %',a,s,f;END IF;
IF (s->>'mixHistorical')::numeric<>1 OR (s->>'mixPrevious')::numeric<>1 OR (f->>'mixPrevious')::numeric<>10 THEN RAISE EXCEPTION 'Mix partition fixture failed';END IF;
END $$;
SELECT 'Foods expansion cannot downgrade Salty critical client: verified' status;

ROLLBACK;

