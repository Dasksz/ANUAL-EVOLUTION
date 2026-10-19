-- Real linked portfolio, no lasting customer changes. Run as database owner.
BEGIN;
SET LOCAL statement_timeout='90s';
CREATE TEMP TABLE attribution_before ON COMMIT DROP AS
 SELECT mes,categoria,metrica,sum(valor) valor FROM private.evolution_client_goal_ownership
 WHERE ano=2026 AND owner_code='324' GROUP BY mes,categoria,metrica;
DO $$
DECLARE client_id text; quota_hash text; import_hash text; version_before text;
BEGIN
 SELECT codcli INTO client_id FROM private.evolution_client_goal_ownership
 WHERE ano=2026 AND owner_code='324' AND valor>0 GROUP BY codcli
 HAVING count(DISTINCT mes)=3 ORDER BY codcli LIMIT 1;
 IF client_id IS NULL THEN RAISE EXCEPTION 'No real portfolio fixture across Aug/Sep/Oct'; END IF;
 SELECT md5(string_agg(q.source_id||':'||q.profile||':'||q.valor,'|' ORDER BY q.source_id,q.profile)) INTO quota_hash
 FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id WHERE s.ano=2026;
 SELECT md5(string_agg(to_jsonb(m)::text,'|' ORDER BY mes,codusur,categoria,metrica)) INTO import_hash FROM metas_sv m WHERE ano=2026;
 version_before:=get_data_version();
 UPDATE data_clients SET rca1='286' WHERE codigo_cliente=client_id;
 IF EXISTS(SELECT 1 FROM private.evolution_client_goal_ownership WHERE ano=2026 AND codcli=client_id AND owner_code<>'286') THEN RAISE EXCEPTION 'Some historical quotas did not return to Valnei'; END IF;
 IF version_before=get_data_version() THEN RAISE EXCEPTION 'Ownership change did not invalidate cached data'; END IF;
 IF EXISTS(
  SELECT 1 FROM attribution_before b LEFT JOIN (
   SELECT mes,categoria,metrica,sum(valor) valor FROM private.evolution_client_goal_ownership WHERE ano=2026 AND owner_code='324' GROUP BY mes,categoria,metrica
  ) a USING(mes,categoria,metrica)
  LEFT JOIN (SELECT mes,categoria,metrica,sum(valor) valor FROM private.evolution_client_goal_ownership WHERE ano=2026 AND codcli=client_id GROUP BY mes,categoria,metrica) c USING(mes,categoria,metrica)
  WHERE b.valor-coalesce(a.valor,0)<>coalesce(c.valor,0)
 ) THEN RAISE EXCEPTION 'Receiver totals do not match the transferred customer quotas'; END IF;
 UPDATE data_clients SET rca1='324' WHERE codigo_cliente=client_id;
 IF EXISTS(
  SELECT 1 FROM attribution_before b FULL JOIN (
   SELECT mes,categoria,metrica,sum(valor) valor FROM private.evolution_client_goal_ownership WHERE ano=2026 AND owner_code='324' GROUP BY mes,categoria,metrica
  ) a USING(mes,categoria,metrica) WHERE a.valor IS DISTINCT FROM b.valor
 ) THEN RAISE EXCEPTION 'Restoring the RCA changed the historical totals'; END IF;
 IF quota_hash IS DISTINCT FROM (SELECT md5(string_agg(q.source_id||':'||q.profile||':'||q.valor,'|' ORDER BY q.source_id,q.profile)) FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id WHERE s.ano=2026) THEN RAISE EXCEPTION 'Historical quotas changed'; END IF;
 IF import_hash IS DISTINCT FROM (SELECT md5(string_agg(to_jsonb(m)::text,'|' ORDER BY mes,codusur,categoria,metrica)) FROM metas_sv m WHERE ano=2026) THEN RAISE EXCEPTION 'Original imports changed'; END IF;
END $$;
ROLLBACK;
SELECT 'PASS: real client returned Ariana -> Valnei -> Ariana across August, September and October; totals, original imports and quotas preserved; cache revision changed' result;
