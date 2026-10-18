-- Run as database owner. Every fixture is isolated and rolled back, including on assertion failure.
BEGIN;
SET LOCAL statement_timeout='50s';
DO $$
DECLARE batch uuid; a numeric; b numeric; u numeric; joint numeric; total numeric; zeros jsonb;
BEGIN
 INSERT INTO private.metas_import_batches(ano,mes,payload) VALUES(2099,10,'[]') RETURNING id INTO batch;
 INSERT INTO private.metas_planilha(ano,mes,nivel,codigo_entidade,nome,categoria,metrica,valor,origem,batch_id)
 VALUES(2099,10,'empresa','TEST_GV','TESTE','707','POS',10,'[]',batch),
 (2099,10,'empresa','TEST_GV','TESTE','pepsico_all','POS',12,'[]',batch),
 (2099,10,'empresa','TEST_GV','TESTE','707','FAT',1000,'[]',batch),
 (2099,10,'empresa','TEST_GV','TESTE','mix_salty','MIX',3,'[]',batch);
 INSERT INTO public.data_summary(ano,mes,filial,cidade,codusur,codsupervisor,codfor,tipovenda,codcli,vlvenda,peso,categoria_produto) VALUES
 (2099,9,'05','CITY_A','TEST','TEST','707','1','__META_TEST_A',100,1,'CHEETOS'),
 (2099,9,'08','CITY_A','TEST','TEST','707','1','__META_TEST_A',100,1,'FANDANGOS'),
 (2099,9,'05','CITY_B','TEST','TEST','707','1','__META_TEST_B',100,1,'FANDANGOS'),
 (2099,9,'08','CITY_B','TEST','TEST','707','1','__META_TEST_C',100,1,'CHEETOS');
 SELECT (e->>'valor')::numeric INTO a FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["CHEETOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO b FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["FANDANGOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO u FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["CHEETOS","FANDANGOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO joint FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["FANDANGOS"],"p_filial":["05"]}')) e WHERE e->>'metrica'='POS';
 IF a IS DISTINCT FROM 7 OR b IS DISTINCT FROM 7 OR u IS DISTINCT FROM 10 OR joint IS DISTINCT FROM 3 THEN
  RAISE EXCEPTION 'Overlap/joint-edge failure: A %, B %, union %, joint %',a,b,u,joint;
 END IF;
 SELECT sum((e->>'valor')::numeric) INTO total FROM (VALUES('CITY_A'),('CITY_B')) cities(city)
 CROSS JOIN LATERAL jsonb_array_elements(private.evolution_dashboard_targets(2099,10,jsonb_build_object('p_cidade',jsonb_build_array(city)))) e WHERE e->>'metrica'='POS';
 IF total IS DISTINCT FROM 12 THEN RAISE EXCEPTION 'Cities must preserve all 12 quotas: %',total; END IF;
 SELECT (e->>'valor')::numeric INTO joint FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["FANDANGOS"],"p_filial":["05"]}')) e WHERE e->>'metrica'='FAT';
 IF joint IS DISTINCT FROM 250 THEN RAISE EXCEPTION 'Revenue joint allocation: %',joint; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707"],"p_categoria":["CHEETOS"]}')) e WHERE e->>'metrica'='MIX') THEN RAISE EXCEPTION 'Incomplete brand selection redefined full mix'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_fornecedor":["707","708"]}')) e WHERE e->>'metrica'='POS') THEN RAISE EXCEPTION 'Multiple suppliers must not add POS targets'; END IF;
 RAISE NOTICE 'PASS: category overlap, largest remainder, joint branch/category, exclusive cities, revenue weights, mix eligibility and POS supplier restriction.';
END $$;
ROLLBACK;
