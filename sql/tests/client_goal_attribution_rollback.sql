BEGIN;
SET LOCAL statement_timeout='90s';
DO $$
DECLARE snapshot text; remaining numeric; received numeric; p numeric; a numeric; b numeric; u numeric; joint numeric;
BEGIN
 INSERT INTO dim_vendedores(codigo,nome) VALUES('__ATTR_ORIGINAL','VENDEDOR ORIGEM TESTE'),('__ATTR_NEW','VENDEDOR SUBSTITUTO TESTE'),('__ATTR_ABSENT','VENDEDOR SEM META ORIGINAL TESTE');
 INSERT INTO data_clients(codigo_cliente,rca1,cidade,codsupervisor) VALUES
 ('__ATTR_CLIENT_A','__ATTR_ORIGINAL','CITY_A','12'),('__ATTR_CLIENT_B','__ATTR_ORIGINAL','CITY_B','12'),('__ATTR_CLIENT_C','__ATTR_NEW','CITY_A','12');
 INSERT INTO metas_sv(ano,mes,codusur,vendedor_nome,categoria,metrica,valor_ajuste) VALUES
 (2099,10,'__ATTR_ORIGINAL','VENDEDOR ORIGEM TESTE','pepsico_all','FAT',100),
 (2099,10,'__ATTR_ORIGINAL','VENDEDOR ORIGEM TESTE','pepsico_all','VOL',10),
 (2099,10,'__ATTR_ORIGINAL','VENDEDOR ORIGEM TESTE','pepsico_all','POS',5),
 (2099,10,'__ATTR_ORIGINAL','VENDEDOR ORIGEM TESTE','mix_salty','MIX',3),
 (2099,10,'__ATTR_NEW','VENDEDOR SUBSTITUTO TESTE','pepsico_all','FAT',60);
 INSERT INTO data_summary(ano,mes,filial,cidade,codusur,codsupervisor,codfor,tipovenda,codcli,vlvenda,peso,categoria_produto) VALUES
 (2099,9,'05','CITY_A','__ATTR_ORIGINAL','12','707','1','__ATTR_CLIENT_A',100,1,'CHEETOS'),
 (2099,9,'08','CITY_B','__ATTR_ORIGINAL','12','707','1','__ATTR_CLIENT_B',300,3,'FANDANGOS'),
 (2099,9,'08','CITY_A','__ATTR_ORIGINAL','12','707','2','__ATTR_CLIENT_A',10,0,'FANDANGOS'),
 (2099,9,'05','CITY_A','__ATTR_NEW','12','707','1','__ATTR_CLIENT_C',100,1,'CHEETOS');
 PERFORM private.evolution_sync_meta_period(2099,10);
 SELECT (e->>'valor')::numeric INTO a FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ORIGINAL"],"p_categoria":["CHEETOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO b FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ORIGINAL"],"p_categoria":["FANDANGOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO u FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ORIGINAL"],"p_categoria":["CHEETOS","FANDANGOS"]}')) e WHERE e->>'metrica'='POS';
 SELECT (e->>'valor')::numeric INTO joint FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ORIGINAL"],"p_categoria":["FANDANGOS"],"p_filial":["05"]}')) e WHERE e->>'metrica'='POS';
 IF a IS DISTINCT FROM 3 OR b IS DISTINCT FROM 5 OR u IS DISTINCT FROM 5 OR joint IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Ledger overlap or joint edge failed: %, %, %, %',a,b,u,joint; END IF;
 SELECT md5(string_agg(source_id||':'||profile||':'||q.valor,'|' ORDER BY source_id,profile)) INTO snapshot FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id WHERE s.ano=2099;
 UPDATE data_clients SET rca1='__ATTR_NEW' WHERE codigo_cliente='__ATTR_CLIENT_A';
 SELECT sum(valor) INTO remaining FROM private.evolution_client_goal_ownership WHERE ano=2099 AND mes=10 AND owner_code='__ATTR_ORIGINAL' AND categoria='pepsico_all' AND metrica='FAT';
 SELECT sum(valor) INTO received FROM private.evolution_client_goal_ownership WHERE ano=2099 AND mes=10 AND owner_code='__ATTR_NEW' AND categoria='pepsico_all' AND metrica='FAT';
 IF remaining IS DISTINCT FROM 75 OR received IS DISTINCT FROM 85 THEN RAISE EXCEPTION 'Partial transfer wrong: remaining %, recipient %',remaining,received; END IF;
 UPDATE data_clients SET rca1='__ATTR_NEW' WHERE codigo_cliente='__ATTR_CLIENT_B';
 SELECT sum(valor) INTO received FROM private.evolution_client_goal_ownership WHERE ano=2099 AND mes=10 AND owner_code='__ATTR_NEW' AND categoria='pepsico_all' AND metrica='FAT';
 SELECT sum(valor) INTO p FROM private.evolution_client_goal_totals WHERE ano=2099 AND mes=10 AND owner_code='__ATTR_NEW' AND categoria='pepsico_all' AND metrica='FAT';
 IF p IS DISTINCT FROM 160 THEN RAISE EXCEPTION 'Compact totals did not follow current ownership'; END IF;
 IF received IS DISTINCT FROM 160 THEN RAISE EXCEPTION 'Whole transfer must preserve 160: %',received; END IF;
 SELECT (t->>'valor')::numeric INTO remaining FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ORIGINAL"]}')) t WHERE t->>'metrica'='FAT';
 IF remaining IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Previous seller should show explicit zero: %',remaining; END IF;
 UPDATE data_clients SET rca1='__ATTR_ORIGINAL' WHERE codigo_cliente IN('__ATTR_CLIENT_A','__ATTR_CLIENT_B');
 SELECT sum(valor) INTO received FROM private.evolution_client_goal_ownership WHERE ano=2099 AND mes=10 AND owner_code='__ATTR_ORIGINAL' AND categoria='pepsico_all' AND metrica='FAT';
 IF received IS DISTINCT FROM 100 THEN RAISE EXCEPTION 'Restoration must recover the same 100: %',received; END IF;
 UPDATE data_clients SET rca1='__ATTR_ABSENT' WHERE codigo_cliente='__ATTR_CLIENT_A';
 SELECT (t->>'valor')::numeric INTO received FROM jsonb_array_elements(private.evolution_dashboard_targets(2099,10,'{"p_vendedor":["__ATTR_ABSENT"]}')) t WHERE t->>'metrica'='FAT';
 IF received IS DISTINCT FROM 25 THEN RAISE EXCEPTION 'Recipient absent from original import must receive 25: %',received; END IF;
 IF EXISTS(SELECT 1 FROM metas_sv WHERE ano=2099 AND codusur='__ATTR_ABSENT') THEN RAISE EXCEPTION 'Derived attribution created a fake original import'; END IF;
 UPDATE data_clients SET rca1=NULL WHERE codigo_cliente='__ATTR_CLIENT_A';
 SELECT sum(valor) INTO p FROM private.evolution_client_goal_ownership WHERE ano=2099 AND mes=10 AND owner_code='__PENDENTE__' AND categoria='pepsico_all' AND metrica='FAT';
 IF p IS DISTINCT FROM 25 THEN RAISE EXCEPTION 'Unassigned client must keep its 25 pending: %',p; END IF;
 UPDATE data_clients SET rca1='UNKNOWN_RCA' WHERE codigo_cliente='__ATTR_CLIENT_A';
 IF EXISTS(SELECT 1 FROM private.evolution_client_goal_ownership WHERE ano=2099 AND codcli='__ATTR_CLIENT_A' AND owner_code<>'__PENDENTE__') THEN RAISE EXCEPTION 'Unknown RCA was accepted'; END IF;
 IF snapshot IS DISTINCT FROM (SELECT md5(string_agg(source_id||':'||profile||':'||q.valor,'|' ORDER BY source_id,profile)) FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id WHERE s.ano=2099) THEN RAISE EXCEPTION 'Client reassignment rebuilt quotas'; END IF;
 IF EXISTS(SELECT 1 FROM private.evolution_client_goal_ownership WHERE ano=2099 AND metrica IN('POS','MIX') AND valor<>trunc(valor)) THEN RAISE EXCEPTION 'Client counts became fractional'; END IF;
 IF EXISTS(SELECT 1 FROM private.meta_client_sources s LEFT JOIN private.meta_client_shares q ON q.source_id=s.id WHERE s.ano=2099 AND s.active GROUP BY s.id HAVING sum(q.valor)<>s.valor) THEN RAISE EXCEPTION 'Targets not preserved 100 percent'; END IF;
 IF (SELECT valor_ajuste FROM metas_sv WHERE ano=2099 AND codusur='__ATTR_ORIGINAL' AND metrica='FAT')<>100 THEN RAISE EXCEPTION 'Original import changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.meta_attribution_events WHERE event='responsavel_alterado' AND details->>'cliente'='__ATTR_CLIENT_A') THEN RAISE EXCEPTION 'Ownership transfer was not audited'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS: partial/whole/return transfers, absent recipient in original spreadsheet, pending ownership, fixed quotas, integers, 100 percent conservation and audit trail' result;
