-- Apply after client_goal_attribution*.sql. Evidence is loaded separately into private storage.
CREATE TABLE private.meta_portfolio_archives (
 ano integer NOT NULL, mes integer NOT NULL CHECK(mes BETWEEN 1 AND 12),
 codcli text NOT NULL, original_seller text NOT NULL,
 source_file text NOT NULL, source_hash text NOT NULL, source_row integer NOT NULL,
 basis text NOT NULL CHECK(basis IN ('cadastro_arquivado','vendas_arquivadas')),
 PRIMARY KEY(ano,mes,codcli)
);
CREATE INDEX meta_portfolio_archive_seller_idx ON private.meta_portfolio_archives(ano,original_seller,mes);
ALTER TABLE private.meta_portfolio_archives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.meta_portfolio_archives FROM PUBLIC,anon,authenticated;
ALTER TABLE private.meta_portfolio_clients ADD COLUMN basis text NOT NULL DEFAULT 'cadastro_atual',
 ADD COLUMN evidence_month integer, ADD COLUMN source_hash text;

-- The original portfolio is fixed once; current cadastro controls only the recipient.
-- Prefer the reference month. Retired RCAs use their latest available earlier portfolio.
-- The earliest later snapshot is an explicit fallback when no older evidence exists.
CREATE FUNCTION private.evolution_seed_archived_portfolios(y integer,mo integer) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 WITH sources AS (
  SELECT DISTINCT source_seller FROM private.meta_client_sources s WHERE ano=y AND mes=mo AND active
   AND NOT EXISTS(SELECT 1 FROM private.meta_portfolio_clients p WHERE p.ano=y AND p.mes=mo AND p.source_seller=s.source_seller)
 ), periods AS (
  SELECT s.source_seller,coalesce(max(a.mes) FILTER(WHERE a.mes<=mo),min(a.mes)) evidence_month
  FROM sources s JOIN private.meta_portfolio_archives a ON a.ano=y AND a.original_seller=s.source_seller
  GROUP BY s.source_seller
 ), candidates AS (
  SELECT a.*,row_number() OVER(PARTITION BY a.codcli ORDER BY abs(a.mes-mo),a.mes DESC,a.original_seller) priority
  FROM periods p JOIN private.meta_portfolio_archives a
   ON a.ano=y AND a.mes=p.evidence_month AND a.original_seller=p.source_seller
 ) INSERT INTO private.meta_portfolio_clients(ano,mes,source_seller,codcli,basis,evidence_month,source_hash)
 SELECT y,mo,original_seller,codcli,basis,mes,source_hash FROM candidates WHERE priority=1
 ON CONFLICT(ano,mes,codcli) DO NOTHING;
 UPDATE private.meta_client_sources s SET portfolio_seller=source_seller
 WHERE ano=y AND mes=mo AND EXISTS(SELECT 1 FROM private.meta_portfolio_clients p
  WHERE p.ano=y AND p.mes=mo AND p.source_seller=s.source_seller);
END $$;
REVOKE ALL ON FUNCTION private.evolution_seed_archived_portfolios(integer,integer) FROM PUBLIC,anon,authenticated;

-- Insert the archive seeding step before the current-cadastro fallback in the existing synchronizer.
DO $$ DECLARE def text; BEGIN
 SELECT pg_get_functiondef('private.evolution_sync_meta_period(integer,integer,boolean)'::regprocedure) INTO def;
 IF position('PERFORM private.evolution_seed_archived_portfolios' IN def)=0 THEN
  def:=replace(def,'-- Membership is captured once.',
   'PERFORM private.evolution_seed_archived_portfolios(y,mo);'||chr(10)||' -- Membership is captured once.');
  EXECUTE def;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_data_version() RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE last_update timestamptz; portfolio text; farol text; targets timestamptz;
BEGIN
 PERFORM private.evolution_assert_approved();
 SELECT max(created_at) INTO last_update FROM public.data_summary;
 SELECT md5(coalesce(string_agg(codigo_cliente||':'||coalesce(rca1,'')||':'||coalesce(codsupervisor,''),'|' ORDER BY codigo_cliente),'')) INTO portfolio FROM public.data_clients;
 SELECT coalesce(source_hash,'') INTO farol FROM public.farol_sync_state WHERE id;
 SELECT max(updated_at) INTO targets FROM private.meta_attribution_periods;
 RETURN coalesce(last_update::text,'1970-01-01 00:00:00+00')||':boxes-packaging-v2:portfolio:'||portfolio
  ||':farol:'||coalesce(farol,'')||':targets:'||coalesce(targets::text,'');
END $$;
ALTER FUNCTION public.import_metas_planilha(jsonb) SET statement_timeout='120s';
ALTER FUNCTION public.bind_meta_portfolio(integer,integer,text,text[]) SET statement_timeout='120s';

-- PDEV is carried when supplied, but blank optional audit cells must not prevent a historical import.
-- All 23 commercial indicators remain mandatory. Never fill blank PDEV with an invented zero.
DO $$ DECLARE def text; BEGIN
 SELECT pg_get_functiondef('private.evolution_import_targets_original(jsonb)'::regprocedure) INTO def;
 def:=replace(def,'HAVING count(*)<>24',
  'HAVING count(*) FILTER(WHERE e->>''categoria''<>''pedev'')<>23 OR count(*)>24');
 def:=replace(def,'os 24 indicadores do modelo, incluindo auditoria PDEV.',
  'os 23 indicadores comerciais do modelo. Auditoria PDEV é opcional quando a célula estiver vazia.');
 EXECUTE def;
END $$;
