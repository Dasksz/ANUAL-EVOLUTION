-- Immutable import sources and fixed client/profile quotas. Ownership is resolved at read time.
CREATE TABLE private.meta_initial_portfolio_links (
 original_seller text PRIMARY KEY, portfolio_seller text NOT NULL, reason text NOT NULL
);
-- Business identities explicitly confirmed by the user; used only to establish the initial client baseline.
INSERT INTO private.meta_initial_portfolio_links VALUES
 ('286','324','FÈrias de Valnei: carteira assumida por Ariana, confirmado pelo usu·rio'),
 ('172','312','FÈrias de JosÈ Carlos: carteira unificada com Edinaldo, confirmado pelo usu·rio');
ALTER TABLE private.meta_initial_portfolio_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.meta_initial_portfolio_links FROM PUBLIC,anon,authenticated;
CREATE TABLE private.meta_portfolio_clients (
 ano integer NOT NULL, mes integer NOT NULL, source_seller text NOT NULL, codcli text NOT NULL,
 linked_at timestamptz NOT NULL DEFAULT clock_timestamp(), linked_by uuid,
 PRIMARY KEY(ano,mes,codcli)
);
CREATE INDEX meta_portfolio_source_idx ON private.meta_portfolio_clients(ano,mes,source_seller);
CREATE TABLE private.meta_client_sources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ano integer NOT NULL, mes integer NOT NULL,
 source_seller text NOT NULL, source_name text NOT NULL, parent text, portfolio_seller text NOT NULL,
 categoria text NOT NULL, metrica text NOT NULL, valor numeric NOT NULL CHECK(valor>=0),
 scale numeric NOT NULL CHECK(scale>0), active boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(ano,mes,source_seller,categoria,metrica)
);
CREATE TABLE private.meta_client_shares (
 source_id uuid NOT NULL REFERENCES private.meta_client_sources(id), profile text NOT NULL,
 codcli text, weight numeric NOT NULL CHECK(weight>0), valor numeric NOT NULL CHECK(valor>=0),
 edges jsonb NOT NULL DEFAULT '[]', basis text NOT NULL,
 PRIMARY KEY(source_id,profile)
);
CREATE INDEX meta_client_shares_client_idx ON private.meta_client_shares(codcli);
CREATE TABLE private.meta_attribution_periods (
 ano integer NOT NULL, mes integer NOT NULL, source_hash text NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(), PRIMARY KEY(ano,mes)
);
CREATE TABLE private.meta_attribution_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(), actor uuid,
 event text NOT NULL, details jsonb NOT NULL
);
ALTER TABLE private.meta_portfolio_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.meta_client_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.meta_client_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.meta_attribution_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.meta_attribution_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.meta_portfolio_clients,private.meta_client_sources,private.meta_client_shares,
 private.meta_attribution_periods,private.meta_attribution_events FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.evolution_rebuild_client_shares(y integer,mo integer,only_seller text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp SET work_mem='90MB' AS $$
BEGIN
 DELETE FROM private.meta_client_shares q USING private.meta_client_sources s
 WHERE q.source_id=s.id AND s.ano=y AND s.mes=mo AND (only_seller IS NULL OR s.source_seller=only_seller);
 WITH sources AS MATERIALIZED (
  SELECT * FROM private.meta_client_sources s WHERE ano=y AND mes=mo AND active
   AND (only_seller IS NULL OR source_seller=only_seller)
 ), brands AS MATERIALIZED (
  SELECT categoria_produto,min(upper(mix_marca)) brand FROM public.dim_produtos GROUP BY categoria_produto
 ), raw AS MATERIALIZED (
  SELECT d.id,d.ano,d.mes,d.codcli,d.filial,d.cidade,d.ramo,d.codfor,d.categoria_produto,d.tipovenda,
   d.vlvenda,d.peso,coalesce(b.brand,upper(d.categoria_produto)) brand,p.source_seller
  FROM private.meta_portfolio_clients p JOIN public.data_summary d ON d.codcli=p.codcli
  LEFT JOIN brands b USING(categoria_produto)
  WHERE p.ano=y AND p.mes=mo AND (only_seller IS NULL OR p.source_seller IN (SELECT portfolio_seller FROM sources))
   AND d.ano BETWEEN y-1 AND y AND d.ano*12+d.mes BETWEEN y*12+mo-3 AND y*12+mo-1
   AND d.tipovenda NOT IN ('5','11')
 ), candidates AS MATERIALIZED (
  SELECT s.id,s.categoria,s.metrica,r.codcli,
   CASE WHEN s.metrica IN ('POS','MIX') THEN concat(r.ano,'/',r.mes,'/',r.codcli) ELSE md5(jsonb_build_array(r.codcli,r.filial,r.cidade,r.ramo,r.codfor,r.categoria_produto)::text) END profile,
   CASE s.metrica WHEN 'FAT' THEN sum(greatest(r.vlvenda,0)) WHEN 'VOL' THEN sum(greatest(r.peso,0)) ELSE 1 END weight,
   jsonb_agg(DISTINCT jsonb_build_object('filial',r.filial,'cidade',upper(r.cidade),
     'rede',upper(coalesce(nullif(trim(r.ramo),''),'S/ REDE')),'categoria',upper(r.categoria_produto),'marca',r.brand,'fornecedor',r.codfor)) edges,
   array_agg(DISTINCT r.brand) brands
  FROM sources s JOIN raw r ON r.source_seller=s.portfolio_seller
   AND (CASE
 WHEN s.categoria IN ('pepsico_all','pedev') THEN true
 WHEN s.categoria IN ('total_elma','tonelada_elma','mix_salty') THEN r.codfor IN ('707','708','752')
 WHEN s.categoria IN ('total_foods','tonelada_foods','mix_foods','1119') THEN r.codfor LIKE '1119%'
 WHEN s.categoria='1119_QUAKER_KEROCOCO' THEN r.codfor='1119_QUAKER_KEROCOCO' OR r.brand IN ('QUAKER','KEROCOCO')
 WHEN s.categoria='1119_QUAKER' THEN r.brand='QUAKER'
 WHEN s.categoria='1119_KEROCOCO' THEN r.brand='KEROCOCO'
 WHEN s.categoria='1119_TODDY' THEN r.codfor=s.categoria OR r.brand='TODDY'
 WHEN s.categoria='1119_TODDYNHO' THEN r.codfor=s.categoria OR r.brand='TODDYNHO'
 ELSE r.codfor=s.categoria END)
   AND ((s.metrica IN ('POS','MIX') AND r.vlvenda>0) OR (s.metrica IN ('FAT','VOL') AND r.tipovenda IN ('1','9')))
  GROUP BY s.id,s.categoria,s.metrica,r.codcli,
   CASE WHEN s.metrica IN ('POS','MIX') THEN concat(r.ano,'/',r.mes,'/',r.codcli) ELSE md5(jsonb_build_array(r.codcli,r.filial,r.cidade,r.ramo,r.codfor,r.categoria_produto)::text) END
 ), qualified AS MATERIALIZED (
  SELECT * FROM candidates WHERE weight>0 AND (metrica<>'MIX'
   OR (categoria='mix_salty' AND brands @> ARRAY['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA'])
   OR (categoria='mix_foods' AND brands @> ARRAY['TODDYNHO','TODDY','QUAKER','KEROCOCO']))
 ), basis AS MATERIALIZED (
  SELECT id,profile,codcli,weight,edges,'historico_trimestral'::text kind FROM qualified
  UNION ALL
  -- No eligible purchases: the complete target still belongs to the identifiable portfolio.
  SELECT s.id,'carteira/'||p.codcli,p.codcli,1,
   jsonb_build_array(jsonb_build_object('cidade',upper(c.cidade),'rede',upper(coalesce(nullif(trim(c.ramo),''),'S/ REDE')))),
   'carteira_sem_historico'
  FROM sources s JOIN private.meta_portfolio_clients p ON p.ano=y AND p.mes=mo AND p.source_seller=s.portfolio_seller
  LEFT JOIN public.data_clients c ON c.codigo_cliente=p.codcli
  WHERE NOT EXISTS(SELECT 1 FROM qualified q WHERE q.id=s.id)
  UNION ALL
  SELECT s.id,'pendente',NULL::text,1,'[]'::jsonb,'carteira_nao_identificada' FROM sources s
  WHERE NOT EXISTS(SELECT 1 FROM private.meta_portfolio_clients p WHERE p.ano=y AND p.mes=mo AND p.source_seller=s.portfolio_seller)
 ), exact AS MATERIALIZED (
  SELECT b.*,s.valor,s.scale,(s.valor*s.scale)*b.weight/sum(b.weight) OVER(PARTITION BY b.id) quota
  FROM basis b JOIN sources s USING(id)
 ), ranked AS MATERIALIZED (
  SELECT *,row_number() OVER(PARTITION BY id ORDER BY quota-floor(quota) DESC,profile) rank,
   valor*scale-sum(floor(quota)) OVER(PARTITION BY id) remainder FROM exact
 ) INSERT INTO private.meta_client_shares(source_id,profile,codcli,weight,valor,edges,basis)
 SELECT id,profile,codcli,weight,(floor(quota)+CASE WHEN rank<=floor(remainder) THEN 1 ELSE 0 END
   +CASE WHEN rank=1 THEN remainder-floor(remainder) ELSE 0 END)/scale,edges,kind FROM ranked;
END $$;

CREATE FUNCTION private.evolution_sync_meta_period(y integer,mo integer,force_rebuild boolean DEFAULT false) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE signature text; previous text;
BEGIN
 SELECT md5(coalesce(string_agg(concat_ws('|',codigo_entidade,nome,supervisor_codigo,categoria,metrica,valor),E'\n'
  ORDER BY codigo_entidade,categoria,metrica),'')) INTO signature
 FROM private.evolution_official_targets WHERE ano=y AND mes=mo AND nivel='vendedor';
 SELECT source_hash INTO previous FROM private.meta_attribution_periods WHERE ano=y AND mes=mo;
 IF signature=previous AND NOT force_rebuild THEN RETURN; END IF;
 PERFORM pg_advisory_xact_lock(20261019,y*100+mo);
 -- Recheck after waiting for a simultaneous import/read.
 SELECT source_hash INTO previous FROM private.meta_attribution_periods WHERE ano=y AND mes=mo;
 IF signature=previous AND NOT force_rebuild THEN RETURN; END IF;
 UPDATE private.meta_client_sources SET active=false WHERE ano=y AND mes=mo;
 INSERT INTO private.meta_client_sources(ano,mes,source_seller,source_name,parent,categoria,metrica,valor,scale,active,portfolio_seller)
 SELECT ano,mes,private.evolution_seller_code(codigo_entidade),nome,supervisor_codigo,categoria,metrica,valor,
  CASE metrica WHEN 'FAT' THEN 100 WHEN 'VOL' THEN 1000 ELSE 1 END,true,
 coalesce((SELECT s0.portfolio_seller FROM private.meta_client_sources s0 WHERE s0.ano=y AND s0.mes=mo AND s0.source_seller=private.evolution_seller_code(t.codigo_entidade) LIMIT 1),
  (SELECT link.portfolio_seller FROM private.meta_initial_portfolio_links link
   WHERE link.original_seller=private.evolution_seller_code(t.codigo_entidade)
    AND NOT EXISTS(SELECT 1 FROM public.data_clients c WHERE private.evolution_seller_code(c.rca1)=link.original_seller)
    AND EXISTS(SELECT 1 FROM public.data_clients c WHERE private.evolution_seller_code(c.rca1)=link.portfolio_seller)),
  private.evolution_seller_code(t.codigo_entidade))
 FROM private.evolution_official_targets t WHERE ano=y AND mes=mo AND nivel='vendedor'
 ON CONFLICT(ano,mes,source_seller,categoria,metrica) DO UPDATE SET
  source_name=excluded.source_name,parent=excluded.parent,valor=excluded.valor,active=true,updated_at=clock_timestamp();
 -- Membership is captured once. Changing the current RCA must never rebuild these weights.
 INSERT INTO private.meta_portfolio_clients(ano,mes,source_seller,codcli)
 SELECT y,mo,s.source_seller,c.codigo_cliente FROM
  (SELECT DISTINCT portfolio_seller AS source_seller FROM private.meta_client_sources WHERE ano=y AND mes=mo AND active) s
 JOIN public.data_clients c ON private.evolution_seller_code(nullif(trim(c.rca1),''))=s.source_seller
 WHERE NOT EXISTS(SELECT 1 FROM private.meta_portfolio_clients p WHERE p.ano=y AND p.mes=mo AND p.source_seller=s.source_seller)
 ON CONFLICT(ano,mes,codcli) DO NOTHING;
 ANALYZE private.meta_client_sources;
 ANALYZE private.meta_portfolio_clients;
 PERFORM private.evolution_rebuild_client_shares(y,mo);
 IF EXISTS(SELECT 1 FROM private.meta_client_sources s LEFT JOIN private.meta_client_shares q ON q.source_id=s.id
  WHERE s.ano=y AND s.mes=mo AND s.active GROUP BY s.id,s.valor HAVING coalesce(sum(q.valor),0)<>s.valor) THEN
  RAISE EXCEPTION 'Falha de concilia√ß√£o: a distribui√ß√£o deve preservar 100%% de cada meta.';
 END IF;
 INSERT INTO private.meta_attribution_periods VALUES(y,mo,signature,clock_timestamp())
 ON CONFLICT(ano,mes) DO UPDATE SET source_hash=excluded.source_hash,updated_at=excluded.updated_at;
 INSERT INTO private.meta_attribution_events(actor,event,details) VALUES(auth.uid(),'metas_distribuidas',jsonb_build_object('ano',y,'mes',mo,'source_hash',signature));
END $$;

-- Live ownership. Deleted, unassigned and unknown RCA clients keep their quotas in the pending bucket.
CREATE VIEW private.evolution_client_goal_ownership AS
 SELECT q.*,s.ano,s.mes,s.source_seller,s.source_name,s.parent source_parent,s.categoria,s.metrica,s.valor source_value,
  coalesce(d.codigo,'__PENDENTE__') owner_code,
  coalesce(d.nome,'PENDENTE DE ATRIBUI√á√ÉO') owner_name,
  CASE WHEN d.codigo IS NOT NULL THEN nullif(trim(c.codsupervisor),'') END owner_parent
 FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id AND s.active
 LEFT JOIN public.data_clients c ON c.codigo_cliente=q.codcli
 LEFT JOIN public.dim_vendedores d ON d.codigo=private.evolution_seller_code(nullif(trim(c.rca1),''))
  AND upper(d.nome) NOT LIKE 'INATIVOS%' AND upper(d.codigo) NOT LIKE 'INAT%';
REVOKE ALL ON private.evolution_client_goal_ownership FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.evolution_log_client_goal_owner() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE old_code text; new_code text; client_code text;
BEGIN
 IF TG_OP<>'INSERT' THEN old_code:=OLD.rca1; client_code:=OLD.codigo_cliente; END IF;
 IF TG_OP<>'DELETE' THEN new_code:=NEW.rca1; client_code:=NEW.codigo_cliente; END IF;
 IF old_code IS DISTINCT FROM new_code AND EXISTS(SELECT 1 FROM private.meta_portfolio_clients WHERE codcli=client_code) THEN
  INSERT INTO private.meta_attribution_events(actor,event,details) VALUES(auth.uid(),'responsavel_alterado',
   jsonb_build_object('cliente',client_code,'anterior',old_code,'atual',new_code,'operacao',TG_OP));
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER evolution_client_goal_owner AFTER INSERT OR DELETE OR UPDATE OF rca1 ON public.data_clients
 FOR EACH ROW EXECUTE FUNCTION private.evolution_log_client_goal_owner();

CREATE FUNCTION public.bind_meta_portfolio(p_ano integer,p_mes integer,p_source_seller text,p_clientes text[]) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE affected text[]; code text;
BEGIN
 PERFORM private.evolution_assert_approved();
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Acesso negado.'; END IF;
 code:=private.evolution_seller_code(p_source_seller);
 PERFORM private.evolution_sync_meta_period(p_ano,p_mes);
 IF NOT EXISTS(SELECT 1 FROM private.meta_client_sources WHERE ano=p_ano AND mes=p_mes AND source_seller=code AND active) THEN RAISE EXCEPTION 'Carteira original n√£o encontrada nesse per√≠odo.'; END IF;
 IF coalesce(cardinality(p_clientes),0)=0 OR EXISTS(SELECT 1 FROM unnest(p_clientes) q WHERE q IS NULL OR NOT EXISTS(SELECT 1 FROM data_clients c WHERE c.codigo_cliente=q)) THEN RAISE EXCEPTION 'Informe c√≥digos de clientes existentes no cadastro.'; END IF;
 PERFORM pg_advisory_xact_lock(20261019,p_ano*100+p_mes);
 SELECT array_agg(DISTINCT source_seller) INTO affected FROM private.meta_portfolio_clients WHERE ano=p_ano AND mes=p_mes AND (source_seller=code OR codcli=ANY(p_clientes));
 INSERT INTO private.meta_attribution_events(actor,event,details)
 SELECT auth.uid(),'vinculo_original_corrigido',jsonb_build_object('ano',p_ano,'mes',p_mes,'origem',code,
  'clientes',p_clientes,'vinculos_anteriores',coalesce(jsonb_agg(to_jsonb(p)),'[]')) FROM private.meta_portfolio_clients p
 WHERE ano=p_ano AND mes=p_mes AND (source_seller=code OR codcli=ANY(p_clientes));
 DELETE FROM private.meta_portfolio_clients WHERE ano=p_ano AND mes=p_mes AND source_seller=code;
 INSERT INTO private.meta_portfolio_clients(ano,mes,source_seller,codcli,linked_by)
 SELECT p_ano,p_mes,code,q,auth.uid() FROM (SELECT DISTINCT unnest(p_clientes) q) ids
 ON CONFLICT(ano,mes,codcli) DO UPDATE SET source_seller=excluded.source_seller,linked_at=clock_timestamp(),linked_by=excluded.linked_by;
 UPDATE private.meta_client_sources SET portfolio_seller=code WHERE ano=p_ano AND mes=p_mes AND source_seller=code;
 PERFORM private.evolution_rebuild_client_shares(p_ano,p_mes);
 UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp() WHERE ano=p_ano AND mes=p_mes;
 RETURN jsonb_build_object('clientes',cardinality(p_clientes),'ano',p_ano,'mes',p_mes);
END $$;
REVOKE ALL ON FUNCTION public.bind_meta_portfolio(integer,integer,text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bind_meta_portfolio(integer,integer,text,text[]) TO authenticated;

CREATE FUNCTION public.get_meta_attribution_status(p_ano integer,p_mes integer DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 WITH pending AS (
  SELECT mes,source_seller,source_name,categoria,metrica,sum(valor) valor
  FROM private.evolution_client_goal_ownership WHERE ano=p_ano AND (p_mes IS NULL OR mes=p_mes)
   AND owner_code='__PENDENTE__' AND categoria<>'pedev'
  GROUP BY mes,source_seller,source_name,categoria,metrica HAVING sum(valor)>0
 ), origins AS (
  SELECT DISTINCT source_seller,source_name,mes FROM pending
 ) SELECT jsonb_build_object('pendencias',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pending p),'[]'),
  'carteiras',coalesce((SELECT jsonb_agg(to_jsonb(o)) FROM origins o),'[]'),
  'updated_at',(SELECT max(updated_at) FROM private.meta_attribution_periods WHERE ano=p_ano)) INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_meta_attribution_status(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_meta_attribution_status(integer,integer) TO authenticated;

REVOKE ALL ON FUNCTION private.evolution_rebuild_client_shares(integer,integer,text),
 private.evolution_sync_meta_period(integer,integer,boolean),private.evolution_log_client_goal_owner()
 FROM PUBLIC,anon,authenticated;
