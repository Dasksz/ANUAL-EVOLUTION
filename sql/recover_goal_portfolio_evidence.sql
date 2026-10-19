CREATE TABLE private.meta_portfolio_evidence (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), codcli text NOT NULL, original_seller text NOT NULL,
 observed_on date NOT NULL, source_file text NOT NULL, source_sheet text NOT NULL, source_row integer NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(codcli,original_seller,observed_on,source_file,source_sheet,source_row)
);
ALTER TABLE private.meta_portfolio_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.meta_portfolio_evidence FROM PUBLIC,anon,authenticated;

-- This import accepts evidence extracted from original customer/sales files, never inferred from target amounts.
CREATE FUNCTION private.evolution_recover_goal_portfolios(evidence jsonb,source_codes text[]) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp SET statement_timeout='120s' AS $$
DECLARE period record; code text;
BEGIN
 INSERT INTO private.meta_portfolio_evidence(codcli,original_seller,observed_on,source_file,source_sheet,source_row)
 SELECT client,private.evolution_seller_code(seller),date::date,file,sheet,row
 FROM jsonb_to_recordset(evidence) AS e(client text,seller text,date text,file text,sheet text,row integer)
 ON CONFLICT DO NOTHING;
 FOR period IN SELECT DISTINCT ano,mes FROM private.meta_client_sources WHERE active
  AND source_seller=ANY(source_codes) ORDER BY ano,mes LOOP
  PERFORM pg_advisory_xact_lock(20261019,period.ano*100+period.mes);
  FOREACH code IN ARRAY source_codes LOOP
   IF NOT EXISTS(SELECT 1 FROM private.meta_client_sources WHERE ano=period.ano AND mes=period.mes AND source_seller=code AND active) THEN CONTINUE; END IF;
   -- Only clients still identifiable in the current cadastro participate in the initial rateio.
   -- Archived evidence is retained even if a customer no longer exists in that cadastro.
   WITH latest AS (
    SELECT DISTINCT ON(e.codcli) e.codcli,e.original_seller
    FROM private.meta_portfolio_evidence e
    WHERE e.observed_on<make_date(period.ano,period.mes,1)
    ORDER BY e.codcli,e.observed_on DESC,e.source_file,e.source_row DESC
   ) INSERT INTO private.meta_portfolio_clients(ano,mes,source_seller,codcli)
   SELECT period.ano,period.mes,code,l.codcli FROM latest l JOIN data_clients c ON c.codigo_cliente=l.codcli
   WHERE l.original_seller=code
   ON CONFLICT(ano,mes,codcli) DO UPDATE SET source_seller=excluded.source_seller,linked_at=clock_timestamp();
   IF EXISTS(SELECT 1 FROM private.meta_portfolio_clients WHERE ano=period.ano AND mes=period.mes AND source_seller=code) THEN
    UPDATE private.meta_client_sources SET portfolio_seller=code WHERE ano=period.ano AND mes=period.mes AND source_seller=code;
   END IF;
  END LOOP;
  PERFORM private.evolution_rebuild_client_shares(period.ano,period.mes);
  UPDATE private.meta_attribution_periods SET updated_at=clock_timestamp() WHERE ano=period.ano AND mes=period.mes;
  INSERT INTO private.meta_attribution_events(actor,event,details) VALUES(auth.uid(),'carteira_recuperada_de_arquivo',
   jsonb_build_object('ano',period.ano,'mes',period.mes,'origens',source_codes));
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION private.evolution_recover_goal_portfolios(jsonb,text[]) FROM PUBLIC,anon,authenticated;
