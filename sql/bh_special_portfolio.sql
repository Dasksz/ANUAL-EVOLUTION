-- Versioned percentage allocations. Original spreadsheet values remain authoritative.
CREATE TABLE private.special_portfolio_versions (
 start_ym integer PRIMARY KEY CHECK(start_ym%100 BETWEEN 1 AND 12),
 clients jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT clock_timestamp(), actor uuid
);
ALTER TABLE private.special_portfolio_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.special_portfolio_versions FROM PUBLIC,anon,authenticated;
INSERT INTO private.special_portfolio_versions(start_ym,clients) VALUES(200001,'[{"code":"12034","percent":100}]');
CREATE FUNCTION private.bh_clients(ym integer) RETURNS TABLE(code text,percent numeric)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT e->>'code',(e->>'percent')::numeric FROM
 (SELECT clients FROM private.special_portfolio_versions WHERE start_ym<=ym ORDER BY start_ym DESC LIMIT 1) v,
 jsonb_array_elements(v.clients) e
$$;
REVOKE ALL ON FUNCTION private.bh_clients(integer) FROM PUBLIC,anon,authenticated;
INSERT INTO public.dim_vendedores(codigo,nome) VALUES('BH','BH') ON CONFLICT(codigo) DO UPDATE SET nome=excluded.nome;

-- Assign on summary writes, including refreshes and future imports. Raw files stay intact.
CREATE FUNCTION private.bh_assign_summary() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM private.bh_clients(NEW.ano*100+NEW.mes) c WHERE c.code=NEW.codcli) THEN
  NEW.codusur:='BH'; NEW.codsupervisor:='8';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.bh_assign_summary() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER zz_bh_assign BEFORE INSERT OR UPDATE ON public.data_summary FOR EACH ROW EXECUTE FUNCTION private.bh_assign_summary();
CREATE TRIGGER zz_bh_assign BEFORE INSERT OR UPDATE ON public.data_summary_frequency FOR EACH ROW EXECUTE FUNCTION private.bh_assign_summary();
CREATE FUNCTION private.bh_assign_detail() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM private.bh_clients(extract(year FROM NEW.dtped)::integer*100+extract(month FROM NEW.dtped)::integer) c WHERE c.code=NEW.codcli) THEN
  NEW.codusur:='BH'; NEW.codsupervisor:='8';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.bh_assign_detail() FROM PUBLIC,anon,authenticated;
DO $$ DECLARE t record; BEGIN
 FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'
  AND (table_name ~ '^data_detailed(_[0-9]{4})?$' OR table_name ~ '^data_history(_[0-9]{4})?$')
  AND NOT EXISTS(SELECT 1 FROM pg_inherits i WHERE i.inhrelid=format('public.%I',table_name)::regclass) LOOP
  EXECUTE format('CREATE TRIGGER zz_bh_assign BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.bh_assign_detail()',t.table_name);
 END LOOP;
END $$;

-- Reuse the existing purchase profiles, but impose the chosen client percentages first.
ALTER FUNCTION private.evolution_rebuild_client_shares(integer,integer,text) RENAME TO evolution_rebuild_client_shares_before_bh;
CREATE FUNCTION private.evolution_rebuild_client_shares(y integer,mo integer,only_seller text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF only_seller IS NULL OR only_seller='BALCAO_SP' THEN
  DELETE FROM private.meta_portfolio_clients WHERE ano=y AND mes=mo AND source_seller='BALCAO_SP';
  INSERT INTO private.meta_portfolio_clients(ano,mes,source_seller,codcli)
   SELECT y,mo,'BALCAO_SP',code FROM private.bh_clients(y*100+mo)
   ON CONFLICT(ano,mes,codcli) DO UPDATE SET source_seller=excluded.source_seller;
  UPDATE private.meta_client_sources SET portfolio_seller='BALCAO_SP' WHERE ano=y AND mes=mo AND source_seller='BALCAO_SP';
 END IF;
 PERFORM private.evolution_rebuild_client_shares_detailed(y,mo,only_seller);
 IF only_seller IS NULL OR only_seller='BALCAO_SP' THEN
  -- A client without a qualifying profile still receives its explicit percentage.
  INSERT INTO private.meta_client_shares(source_id,profile,codcli,weight,valor,edges,basis)
  SELECT s.id,'bh/'||c.code,c.code,1,0,
   jsonb_build_array(jsonb_build_object('cidade',upper(d.cidade),'rede',upper(coalesce(nullif(trim(d.ramo),''),'S/ REDE')))),
   'carteira_sem_historico'
  FROM private.meta_client_sources s CROSS JOIN private.bh_clients(y*100+mo) c
  LEFT JOIN public.data_clients d ON d.codigo_cliente=c.code
  WHERE s.ano=y AND s.mes=mo AND s.source_seller='BALCAO_SP' AND s.active
   AND NOT EXISTS(SELECT 1 FROM private.meta_client_shares q WHERE q.source_id=s.id AND q.codcli=c.code);
  WITH quotas AS (
   SELECT q.source_id,q.profile,s.scale,s.valor,
    s.valor*s.scale*c.percent/100*q.weight/sum(q.weight) OVER(PARTITION BY q.source_id,q.codcli) quota
   FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id
   JOIN private.bh_clients(y*100+mo) c ON c.code=q.codcli
   WHERE s.ano=y AND s.mes=mo AND s.source_seller='BALCAO_SP' AND s.active
  ), ranked AS (
   SELECT *,row_number() OVER(PARTITION BY source_id ORDER BY quota-floor(quota) DESC,profile) rn,
    valor*scale-sum(floor(quota)) OVER(PARTITION BY source_id) remainder FROM quotas
  ) UPDATE private.meta_client_shares q SET valor=(floor(r.quota)+CASE WHEN r.rn<=floor(r.remainder) THEN 1 ELSE 0 END
    +CASE WHEN r.rn=1 THEN r.remainder-floor(r.remainder) ELSE 0 END)/r.scale
   FROM ranked r WHERE q.source_id=r.source_id AND q.profile=r.profile;
 END IF;
 PERFORM private.evolution_refresh_client_totals(y,mo);
END $$;
REVOKE ALL ON FUNCTION private.evolution_rebuild_client_shares(integer,integer,text) FROM PUBLIC,anon,authenticated;

-- Both detailed and compact goal readers resolve the same virtual owner.
DO $$ DECLARE v text; BEGIN
 SELECT pg_get_viewdef('private.evolution_client_goal_ownership'::regclass,true) INTO v;
 EXECUTE 'CREATE OR REPLACE VIEW private.evolution_client_goal_ownership AS
 SELECT q.source_id,q.profile,q.codcli,q.weight,q.valor,q.edges,q.basis,q.ano,q.mes,q.source_seller,q.source_name,q.source_parent,q.categoria,q.metrica,q.source_value,
 CASE WHEN b.code IS NOT NULL THEN ''BH'' ELSE q.owner_code END owner_code,
 CASE WHEN b.code IS NOT NULL THEN ''BH'' ELSE q.owner_name END owner_name,
 CASE WHEN b.code IS NOT NULL THEN ''8'' ELSE q.owner_parent END owner_parent
 FROM ('||rtrim(v,E';\n\r ')||') q
 LEFT JOIN LATERAL (SELECT code FROM private.bh_clients(q.ano*100+q.mes) WHERE code=q.codcli) b ON true';
END $$;
CREATE OR REPLACE VIEW private.evolution_client_goal_totals AS
 SELECT s.ano,s.mes,s.categoria,s.metrica,q.valor,
 CASE WHEN b.code IS NOT NULL THEN 'BH' ELSE coalesce(d.codigo,'__PENDENTE__') END owner_code,
 CASE WHEN b.code IS NOT NULL THEN 'BH' ELSE coalesce(d.nome,'PENDENTE DE ATRIBUIÇÃO') END owner_name,
 CASE WHEN b.code IS NOT NULL THEN '8' WHEN d.codigo IS NOT NULL THEN nullif(trim(c.codsupervisor),'') END owner_parent
 FROM private.meta_client_totals q JOIN private.meta_client_sources s ON s.id=q.source_id AND s.active
 LEFT JOIN public.data_clients c ON c.codigo_cliente=q.codcli
 LEFT JOIN public.dim_vendedores d ON d.codigo=private.evolution_seller_code(nullif(trim(c.rca1),''))
  AND upper(d.nome) NOT LIKE 'INATIVOS%' AND upper(d.codigo) NOT LIKE 'INAT%'
 LEFT JOIN LATERAL (SELECT code FROM private.bh_clients(s.ano*100+s.mes) WHERE code=q.codcli) b ON true;
REVOKE ALL ON private.evolution_client_goal_ownership,private.evolution_client_goal_totals FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.bh_reconcile() RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE p record; t text; ym text;
BEGIN
 FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'
  AND (table_name IN ('data_summary','data_summary_frequency') OR table_name ~ '^data_detailed(_[0-9]{4})?$' OR table_name ~ '^data_history(_[0-9]{4})?$')
  AND NOT EXISTS(SELECT 1 FROM pg_inherits i WHERE i.inhrelid=format('public.%I',table_name)::regclass) LOOP
  ym:=CASE WHEN t IN ('data_summary','data_summary_frequency') THEN 's.ano*100+s.mes' ELSE '(extract(year FROM s.dtped)::integer*100+extract(month FROM s.dtped)::integer)' END;
  EXECUTE format('UPDATE public.%I s SET codusur=CASE WHEN EXISTS(SELECT 1 FROM private.bh_clients(%s) b WHERE b.code=s.codcli) THEN ''BH'' ELSE coalesce(private.evolution_seller_code(c.rca1),''BALCAO_SP'') END, codsupervisor=CASE WHEN EXISTS(SELECT 1 FROM private.bh_clients(%s) b WHERE b.code=s.codcli) THEN ''8'' ELSE coalesce(nullif(c.codsupervisor,''''),''8'') END FROM public.data_clients c WHERE c.codigo_cliente=s.codcli AND (s.codusur=''BH'' OR s.codcli IN (SELECT e->>''code'' FROM private.special_portfolio_versions v,jsonb_array_elements(v.clients)e)) AND (s.codusur IS DISTINCT FROM CASE WHEN EXISTS(SELECT 1 FROM private.bh_clients(%s) b WHERE b.code=s.codcli) THEN ''BH'' ELSE private.evolution_seller_code(c.rca1) END OR s.codsupervisor IS DISTINCT FROM ''8'')',t,ym,ym,ym);
 END LOOP;
 FOR p IN SELECT DISTINCT ano,mes FROM private.evolution_official_targets WHERE nivel='vendedor' LOOP
  PERFORM private.evolution_sync_meta_period(p.ano,p.mes);
  PERFORM private.evolution_rebuild_client_shares(p.ano,p.mes,'BALCAO_SP');
 END LOOP;
 UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp();
 DELETE FROM public.cache_filters WHERE nome IN ('BH','BALCAO');
 INSERT INTO public.cache_filters(filial,cidade,superv,nome,codfor,fornecedor,tipovenda,ano,mes,rede,categoria_produto)
 SELECT DISTINCT s.filial,s.cidade,coalesce(sup.nome,'BALCAO'),v.nome,s.codfor,
 CASE s.codfor WHEN '707' THEN 'EXTRUSADOS' WHEN '708' THEN 'Ñ EXTRUSADOS' WHEN '752' THEN 'TORCIDA'
 WHEN '1119_TODDYNHO' THEN 'TODDYNHO' WHEN '1119_TODDY' THEN 'TODDY' WHEN '1119_QUAKER' THEN 'QUAKER'
 WHEN '1119_KEROCOCO' THEN 'KEROCOCO' WHEN '1119_OUTROS' THEN 'FOODS (Outros)' WHEN '1119' THEN 'FOODS (Outros)' ELSE f.nome END,
 s.tipovenda,s.ano,s.mes,s.ramo,s.categoria_produto
 FROM public.data_summary s JOIN public.dim_vendedores v ON v.codigo=s.codusur
 LEFT JOIN public.dim_supervisores sup ON sup.codigo=s.codsupervisor
 LEFT JOIN public.dim_fornecedores f ON f.codigo=s.codfor
 WHERE s.codusur IN ('BH','BALCAO_SP','53');
END $$;
REVOKE ALL ON FUNCTION private.bh_reconcile() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.bh_portfolio_config(p_start_ym integer DEFAULT NULL,p_clients jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog SET statement_timeout='240s' AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT coalesce((public.elma_management_access()->>'allowed')::boolean,false) THEN
  RAISE EXCEPTION 'Acesso exclusivo do administrador master.' USING ERRCODE='42501';
 END IF;
 IF p_clients IS NOT NULL THEN
  IF p_start_ym NOT BETWEEN 200001 AND 210012 OR p_start_ym%100 NOT BETWEEN 1 AND 12 OR p_start_ym IS NULL THEN RAISE EXCEPTION 'Período inválido.'; END IF;
  IF jsonb_typeof(p_clients)<>'array' OR jsonb_array_length(p_clients)=0 THEN RAISE EXCEPTION 'Informe pelo menos um cliente.'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_clients) e WHERE coalesce(e->>'code','') !~ '^[0-9]+$' OR coalesce((e->>'percent')::numeric,0)<=0 OR (e->>'percent')::numeric>100
    OR NOT EXISTS(SELECT 1 FROM public.data_clients c WHERE c.codigo_cliente=e->>'code')) THEN RAISE EXCEPTION 'Cliente inexistente ou percentual inválido.'; END IF;
  IF (SELECT sum((e->>'percent')::numeric) FROM jsonb_array_elements(p_clients)e)<>100 THEN RAISE EXCEPTION 'Os percentuais devem somar exatamente 100%%.'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_clients)e GROUP BY e->>'code' HAVING count(*)>1) THEN RAISE EXCEPTION 'Cliente duplicado.'; END IF;
  PERFORM pg_advisory_xact_lock(20261105,53);
  INSERT INTO private.special_portfolio_versions(start_ym,clients,actor) VALUES(p_start_ym,p_clients,auth.uid())
   ON CONFLICT(start_ym) DO UPDATE SET clients=excluded.clients,actor=excluded.actor,created_at=clock_timestamp();
  INSERT INTO private.meta_attribution_events(actor,event,details) VALUES(auth.uid(),'carteira_bh_configurada',jsonb_build_object('inicio',p_start_ym,'clientes',p_clients));
  PERFORM private.bh_reconcile();
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY start_ym),'[]') INTO result FROM private.special_portfolio_versions v;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.bh_portfolio_config(integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bh_portfolio_config(integer,jsonb) TO authenticated;
SELECT private.bh_reconcile();
