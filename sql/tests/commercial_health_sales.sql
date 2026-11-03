BEGIN;
SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
-- Fixtures roll back; no uploaded sales or catalog records are persisted.
INSERT INTO public.data_clients(codigo_cliente,nomecliente,rca1,codsupervisor) VALUES('999900001','Health test expansion','321','21'),('999900002','Health test ordinary critical','321','21'),('999900003','Health test current purchase','321','21'),('999900004','Health test one positive month','321','21');
INSERT INTO public.data_history(codcli,codusur,codsupervisor,codfor,tipovenda,vlvenda,qtvenda,produto,dtped,dtsaida,filial)
SELECT code,'321','21','707','1',50,1,product,make_date(2026,m,10)::timestamp AT TIME ZONE 'UTC',make_date(2026,m,10)::timestamp AT TIME ZONE 'UTC','1'
FROM unnest(ARRAY['999900001','999900002','999900003','999900004'])code CROSS JOIN generate_series(5,8)m CROSS JOIN unnest(ARRAY['99990001','99990002'])product WHERE code<>'999900004' OR m=8;
INSERT INTO public.data_history(codcli,codusur,codsupervisor,codfor,tipovenda,vlvenda,qtvenda,produto,dtped,dtsaida,filial)
SELECT code,'321','21','707','1',CASE WHEN code='999900001' THEN CASE WHEN product='99990001' THEN 65 ELSE 32.5 END ELSE 130 END,1,product,'2026-09-10'::timestamptz,'2026-09-10'::timestamptz,'1'
FROM unnest(ARRAY['999900001','999900002','999900003','999900004'])code CROSS JOIN unnest(ARRAY['99990001','99990002','99990003'])product WHERE code='999900001' OR product='99990001';
INSERT INTO public.data_detailed(codcli,codusur,codsupervisor,codfor,tipovenda,vlvenda,qtvenda,produto,dtped,dtsaida,filial)
SELECT code,'321','21','707','1',CASE WHEN code='999900003' THEN .01 ELSE 0 END,1,'99990001','2026-10-10'::timestamptz,'2026-10-10'::timestamptz,'1' FROM unnest(ARRAY['999900001','999900002','999900003','999900004'])code;
-- A duplicated whole month in history must not contribute beside current data.
INSERT INTO public.data_history(codcli,codusur,codsupervisor,codfor,tipovenda,vlvenda,qtvenda,produto,dtped,dtsaida,filial) VALUES('999900001','321','21','707','1',9999,1,'99990001','2026-10-10','2026-10-10','1');
DO $$DECLARE d jsonb;r jsonb;mix jsonb;old_version uuid;started timestamptz;BEGIN
 started:=clock_timestamp();d:=public.get_commercial_health_month_v1('2026-10');
 IF clock_timestamp()-started>interval '15 seconds' THEN RAISE EXCEPTION 'Monthly query too slow';END IF;
 IF d->'periods'<>'["2026-05","2026-06","2026-07","2026-08","2026-09","2026-10"]' THEN RAISE EXCEPTION 'October periods incorrect';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900001';
 IF (r->>'current')::numeric<>0 OR r->'history'<>'[100,100,100,100]' OR (r->>'median')::numeric<>100 OR (r->>'mixHistorical')::numeric<>2 OR (r->>'mixPrevious')::numeric<>3 OR r->>'status'<>'ANALISAR' OR r->>'sourceStatus'<>'CRÍTICO' THEN RAISE EXCEPTION 'Formula, deduplication or exact 1.5x expansion failed: %',r;END IF;
 mix:=public.get_commercial_health_mix_month_v1('999900001','2026-10',(d->>'mixVersion')::uuid);
 IF mix->'monthlyCounts'<>'[2,2,2,2,3]' OR (mix->>'historicalAverage')::numeric<>(r->>'mixHistorical')::numeric THEN RAISE EXCEPTION 'Mix detail differs';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900002';IF r->>'status'<>'CRÍTICO' THEN RAISE EXCEPTION 'Critical boundary failed';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900003';IF r->>'status'<>'SEM ALERTA' THEN RAISE EXCEPTION 'R$0.01 current purchase gate failed';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900004';IF r->>'status'<>'SEM ALERTA' THEN RAISE EXCEPTION 'Two positive historical months gate failed';END IF;
 old_version:=(d->>'mixVersion')::uuid;
 UPDATE public.data_detailed SET vlvenda=20 WHERE codcli='999900002';
 UPDATE public.data_clients SET rca1='282',codsupervisor='12' WHERE codigo_cliente='999900001';
 d:=public.get_commercial_health_month_v1('2026-10');
 IF (d->>'mixVersion')::uuid=old_version THEN RAISE EXCEPTION 'Source revision did not change';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900001';IF r->>'sellerCode'<>'282' OR r->>'supervisorCode'<>'12' THEN RAISE EXCEPTION 'Portfolio changes were ignored';END IF;
 SELECT value INTO r FROM jsonb_array_elements(d->'rows') WHERE value->>'code'='999900002';IF (r->>'current')::numeric<>20 OR r->>'status'<>'SEM ALERTA' THEN RAISE EXCEPTION 'Sales correction was ignored';END IF;
 BEGIN PERFORM public.get_commercial_health_mix_month_v1('999900001','2026-10',old_version);RAISE EXCEPTION 'Stale version accepted' USING ERRCODE='22000';EXCEPTION WHEN raise_exception THEN NULL;END;
 d:=public.get_commercial_health_month_v1('2026-01');IF d->'periods'<>'["2025-08","2025-09","2025-10","2025-11","2025-12","2026-01"]' THEN RAISE EXCEPTION 'Year rollover failed';END IF;
 BEGIN PERFORM public.get_commercial_health_month_v1('2099-01');RAISE EXCEPTION 'Unuploaded month accepted' USING ERRCODE='22000';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
END;$$;
-- Latest-month switch is driven by actual uploads, not by the calendar.
DELETE FROM public.data_detailed WHERE dtped>='2026-11-01' AND dtped<'2026-12-01';
DO $$BEGIN IF public.get_commercial_health_month_v1(NULL)->>'competence'<>'2026-10' THEN RAISE EXCEPTION 'November appeared without upload';END IF;END;$$;
INSERT INTO public.data_detailed(codcli,codusur,codsupervisor,codfor,tipovenda,vlvenda,qtvenda,produto,dtped,dtsaida,filial) VALUES('999900001','321','21','707','1',10,1,'99990001','2026-11-03','2026-11-03','1');
DO $$DECLARE d jsonb;BEGIN d:=public.get_commercial_health_month_v1(NULL);IF d->>'competence'<>'2026-11' OR d->'periods'<>'["2026-06","2026-07","2026-08","2026-09","2026-10","2026-11"]' THEN RAISE EXCEPTION 'First November upload did not roll the periods';END IF;END;$$;
SET LOCAL ROLE authenticated;
DO $$DECLARE d jsonb;r jsonb;BEGIN
 d:=public.get_commercial_health_month_v1('2026-10');r:=d->'rows'->0;
 PERFORM public.get_commercial_health_mix_month_v1(r->>'code','2026-10',(d->>'mixVersion')::uuid);
 IF has_function_privilege('anon','public.get_commercial_health_month_v1(text)','EXECUTE') OR has_table_privilege('authenticated','public.commercial_health_source_state','UPDATE') OR has_table_privilege('authenticated','private.commercial_health_sales_source_v1','SELECT') THEN RAISE EXCEPTION 'Unexpected source permissions';END IF;
END;$$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{}',true);
DO $$BEGIN BEGIN PERFORM public.get_commercial_health_month_v1(NULL);RAISE EXCEPTION 'Unauthenticated access accepted' USING ERRCODE='22000';EXCEPTION WHEN insufficient_privilege THEN NULL;END;END;$$;
SELECT 'Validated formulas, 1.5x boundary, monthly history, sales corrections, portfolio changes, month deduplication, November activation, detail parity and authorization. All fixture writes rolled back.' result;
ROLLBACK;
