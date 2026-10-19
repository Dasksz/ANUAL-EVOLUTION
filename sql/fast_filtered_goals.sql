-- Resolve current ownership once per client, instead of once per historical quota.
CREATE OR REPLACE VIEW private.evolution_client_goal_ownership AS
 WITH owners AS MATERIALIZED (
  SELECT c.codigo_cliente,d.codigo,d.nome,
   CASE WHEN d.codigo IS NOT NULL THEN nullif(trim(c.codsupervisor),'') END parent
  FROM public.data_clients c LEFT JOIN public.dim_vendedores d
   ON d.codigo=private.evolution_seller_code(nullif(trim(c.rca1),''))
   AND upper(d.nome) NOT LIKE 'INATIVOS%' AND upper(d.codigo) NOT LIKE 'INAT%'
 )
 SELECT q.*,s.ano,s.mes,s.source_seller,s.source_name,s.parent source_parent,s.categoria,s.metrica,s.valor source_value,
  coalesce(o.codigo,'__PENDENTE__') owner_code,coalesce(o.nome,'PENDENTE DE ATRIBUIÇÃO') owner_name,o.parent owner_parent
 FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id AND s.active
 LEFT JOIN owners o ON o.codigo_cliente=q.codcli;
REVOKE ALL ON private.evolution_client_goal_ownership FROM PUBLIC,anon,authenticated;

-- Permit a fast imported-only read; existing callers retain estimates by default.
DO $patch$ DECLARE def text; BEGIN
 SELECT pg_get_functiondef('private.evolution_dashboard_metas_original(jsonb)'::regprocedure) INTO def;
 IF position('imported_only' IN def)=0 THEN
  def:=replace(def,'IF jsonb_array_length(coalesce(f->''p_cidade'',''[]''))=0',
   'IF coalesce(f->>''imported_only'',''false'')<>''true'' AND jsonb_array_length(coalesce(f->''p_cidade'',''[]''))=0');
  EXECUTE def;
 END IF;
END $patch$;

