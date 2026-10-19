CREATE OR REPLACE FUNCTION public.get_meta_attribution_status(p_ano integer,p_mes integer DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 WITH missing AS MATERIALIZED (
  SELECT q.*,
   CASE WHEN q.codcli IS NULL THEN 'Carteira original ainda não identificada'
    WHEN c.codigo_cliente IS NULL THEN 'Cliente não consta no cadastro atual'
    WHEN nullif(trim(c.rca1),'') IS NULL THEN 'Cliente sem vendedor no cadastro atual'
    ELSE 'Vendedor do cadastro atual sem identificação válida' END reason
  FROM private.evolution_client_goal_ownership q LEFT JOIN data_clients c ON c.codigo_cliente=q.codcli
  WHERE q.ano=p_ano AND (p_mes IS NULL OR q.mes=p_mes)
   AND q.owner_code='__PENDENTE__' AND q.categoria<>'pedev' AND q.valor>0
 ), pending AS (
  SELECT mes,source_seller,source_name,categoria,metrica,sum(valor) valor
  FROM missing GROUP BY mes,source_seller,source_name,categoria,metrica
 ), clients AS (
  SELECT DISTINCT mes,source_seller,source_name,codcli,reason FROM missing
 ), origins AS (
  SELECT DISTINCT source_seller,source_name,mes FROM pending
 ), archive_refs AS (
  SELECT p.mes,s.source_seller,max(s.source_name) source_name,p.basis,p.evidence_month,count(DISTINCT p.codcli) clients
  FROM private.meta_portfolio_clients p JOIN private.meta_client_sources s
   ON s.ano=p.ano AND s.mes=p.mes AND s.source_seller=p.source_seller AND s.active
  WHERE p.ano=p_ano AND (p_mes IS NULL OR p.mes=p_mes)
   AND (p.evidence_month<>p.mes OR p.basis='vendas_arquivadas')
  GROUP BY p.mes,s.source_seller,p.basis,p.evidence_month
 ) SELECT jsonb_build_object('pendencias',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM pending p),'[]'),
  'carteiras',coalesce((SELECT jsonb_agg(to_jsonb(o)) FROM origins o),'[]'),
  'clientes_pendentes',coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY mes,source_name,codcli) FROM clients c),'[]'),
  'referencias',coalesce((SELECT jsonb_agg(to_jsonb(r)) FROM archive_refs r),'[]'),
  'updated_at',(SELECT max(updated_at) FROM private.meta_attribution_periods WHERE ano=p_ano)) INTO result;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_meta_attribution_status(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_meta_attribution_status(integer,integer) TO authenticated;
