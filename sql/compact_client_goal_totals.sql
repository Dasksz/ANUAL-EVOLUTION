-- Compact monthly quotas retain client identity, so current RCA changes remain live.
CREATE TABLE private.meta_client_totals (
 source_id uuid NOT NULL REFERENCES private.meta_client_sources(id),
 client_key text NOT NULL, codcli text, valor numeric NOT NULL,
 PRIMARY KEY(source_id,client_key)
);
CREATE INDEX meta_client_totals_client_idx ON private.meta_client_totals(codcli);
ALTER TABLE private.meta_client_totals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.meta_client_totals FROM PUBLIC,anon,authenticated;
CREATE FUNCTION private.evolution_refresh_client_totals(y integer,mo integer) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 DELETE FROM private.meta_client_totals t USING private.meta_client_sources s WHERE s.id=t.source_id AND s.ano=y AND s.mes=mo;
 INSERT INTO private.meta_client_totals
 SELECT q.source_id,coalesce(q.codcli,'__PENDENTE__'),q.codcli,sum(q.valor)
 FROM private.meta_client_shares q JOIN private.meta_client_sources s ON s.id=q.source_id
 WHERE s.ano=y AND s.mes=mo GROUP BY q.source_id,q.codcli;
END $$;
REVOKE ALL ON FUNCTION private.evolution_refresh_client_totals(integer,integer) FROM PUBLIC,anon,authenticated;
ALTER FUNCTION private.evolution_rebuild_client_shares(integer,integer,text) RENAME TO evolution_rebuild_client_shares_detailed;
CREATE FUNCTION private.evolution_rebuild_client_shares(y integer,mo integer,only_seller text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM private.evolution_rebuild_client_shares_detailed(y,mo,only_seller);
 PERFORM private.evolution_refresh_client_totals(y,mo);
END $$;
REVOKE ALL ON FUNCTION private.evolution_rebuild_client_shares(integer,integer,text) FROM PUBLIC,anon,authenticated;
DO $$ DECLARE p record; BEGIN
 FOR p IN SELECT DISTINCT ano,mes FROM private.meta_client_sources LOOP
  PERFORM private.evolution_refresh_client_totals(p.ano,p.mes);
 END LOOP;
END $$;
CREATE VIEW private.evolution_client_goal_totals AS
WITH owners AS MATERIALIZED (
 SELECT c.codigo_cliente,d.codigo,d.nome,CASE WHEN d.codigo IS NOT NULL THEN nullif(trim(c.codsupervisor),'') END parent
 FROM public.data_clients c LEFT JOIN public.dim_vendedores d ON d.codigo=private.evolution_seller_code(nullif(trim(c.rca1),''))
 AND upper(d.nome) NOT LIKE 'INATIVOS%' AND upper(d.codigo) NOT LIKE 'INAT%'
)
SELECT s.ano,s.mes,s.categoria,s.metrica,q.valor,coalesce(o.codigo,'__PENDENTE__') owner_code,
 coalesce(o.nome,'PENDENTE DE ATRIBUIÇÃO') owner_name,o.parent owner_parent
FROM private.meta_client_totals q JOIN private.meta_client_sources s ON s.id=q.source_id AND s.active
LEFT JOIN owners o ON o.codigo_cliente=q.codcli;
REVOKE ALL ON private.evolution_client_goal_totals FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION private.evolution_attributed_targets(y integer,mo integer,f jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=public,pg_temp SET work_mem='90MB' AS $$
WITH filters AS MATERIALIZED (
 SELECT ARRAY(SELECT upper(private.evolution_seller_code(value)) FROM jsonb_array_elements_text(coalesce(f->'p_vendedor','[]'))) sellers,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_supervisor','[]'))) supervisors,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_fornecedor','[]'))) suppliers,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_categoria','[]'))) categories,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_filial','[]'))) branches,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_cidade','[]'))) cities,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_rede','[]'))) networks
), owned AS MATERIALIZED (
 SELECT q.owner_code,q.owner_name,q.owner_parent,q.categoria,q.metrica,q.valor,q.edges,q.basis
 FROM (
  SELECT owner_code,owner_name,owner_parent,categoria,metrica,valor,edges,basis,ano,mes
  FROM private.evolution_client_goal_ownership
  WHERE EXISTS(SELECT 1 FROM filters WHERE cardinality(branches)+cardinality(cities)+cardinality(networks)+cardinality(categories)+cardinality(suppliers)>0)
  UNION ALL
  SELECT owner_code,owner_name,owner_parent,categoria,metrica,valor,'[]'::jsonb,'resumo_integral',ano,mes
  FROM private.evolution_client_goal_totals
  WHERE EXISTS(SELECT 1 FROM filters WHERE cardinality(branches)+cardinality(cities)+cardinality(networks)+cardinality(categories)+cardinality(suppliers)=0)
 ) q CROSS JOIN filters f
 WHERE q.ano=y AND q.mes=mo AND q.categoria<>'pedev'
 AND (cardinality(f.sellers)=0 OR upper(q.owner_code)=ANY(f.sellers) OR upper(q.owner_name)=ANY(f.sellers))
 AND (cardinality(f.supervisors)=0 OR upper(q.owner_parent)=ANY(f.supervisors)
  OR EXISTS(SELECT 1 FROM dim_supervisores d WHERE d.codigo=q.owner_parent AND upper(trim(d.nome))=ANY(f.supervisors)))
), scoped AS MATERIALIZED (
 SELECT q.*,CASE WHEN cardinality(f.branches)=0 AND cardinality(f.cities)=0 AND cardinality(f.networks)=0
  AND cardinality(f.categories)=0 AND (cardinality(f.suppliers)=0 OR upper(q.categoria)=ANY(f.suppliers)
   OR ('1119'=ANY(f.suppliers) AND q.categoria IN ('total_foods','tonelada_foods','mix_foods','1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO'))
   OR (f.suppliers @> ARRAY['707','708','752'] AND q.categoria IN ('total_elma','tonelada_elma','mix_salty')))
 THEN true ELSE EXISTS(
  SELECT 1 FROM jsonb_array_elements(q.edges) e WHERE
   (cardinality(f.branches)=0 OR upper(e->>'filial')=ANY(f.branches))
   AND (cardinality(f.cities)=0 OR e->>'cidade'=ANY(f.cities))
   AND (cardinality(f.networks)=0 OR e->>'rede'=ANY(f.networks)
    OR (f.networks && ARRAY['C/ REDE','COM_RAMO'] AND e->>'rede'<>'S/ REDE')
    OR (f.networks && ARRAY['S/ REDE','SEM_RAMO'] AND e->>'rede'='S/ REDE'))
   AND (cardinality(f.categories)=0 OR e->>'categoria'=ANY(f.categories) OR e->>'marca'=ANY(f.categories))
   AND (cardinality(f.suppliers)=0 OR EXISTS(SELECT 1 FROM unnest(f.suppliers) supplier
    WHERE private.evolution_target_contains(supplier,e->>'fornecedor',e->>'marca')))
 ) END selected,
 q.basis<>'historico_trimestral' AND (cardinality(f.branches)>0 OR cardinality(f.categories)>0
  OR (cardinality(f.suppliers)>0 AND NOT (upper(q.categoria)=ANY(f.suppliers)))) AND q.valor>0 unknown_scope
 FROM owned q CROSS JOIN filters f
), totals AS MATERIALIZED (
 SELECT owner_code code,owner_name name,max(owner_parent) parent,categoria,metrica,sum(valor) original,
 CASE WHEN bool_or(unknown_scope) THEN NULL ELSE coalesce(sum(valor) FILTER(WHERE selected),0) END value
 FROM scoped GROUP BY owner_code,owner_name,categoria,metrica
), zero_owners AS MATERIALIZED (
 SELECT DISTINCT s.source_seller code,coalesce(d.nome,s.source_name) name,s.parent,s.categoria,s.metrica,0::numeric original,0::numeric value
 FROM private.meta_client_sources s LEFT JOIN dim_vendedores d ON d.codigo=s.source_seller CROSS JOIN filters f
 WHERE s.ano=y AND s.mes=mo AND s.active AND s.categoria<>'pedev'
 AND (cardinality(f.sellers)=0 OR upper(s.source_seller)=ANY(f.sellers) OR upper(coalesce(d.nome,s.source_name))=ANY(f.sellers))
 AND (cardinality(f.supervisors)=0 OR upper(s.parent)=ANY(f.supervisors))
 AND NOT EXISTS(SELECT 1 FROM totals t WHERE t.code=s.source_seller AND t.categoria=s.categoria AND t.metrica=s.metrica)
), all_targets AS MATERIALIZED (
 SELECT * FROM totals UNION ALL SELECT * FROM zero_owners
), targets AS MATERIALIZED (
 SELECT t.* FROM all_targets t CROSS JOIN filters f
 WHERE $3->>'all_metrics'='true'
 OR (metrica='FAT' AND ((cardinality(f.suppliers)=0 AND (categoria='pepsico_all' OR
  (categoria IN ('707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO')
   AND NOT EXISTS(SELECT 1 FROM all_targets a WHERE a.code=t.code AND a.categoria='pepsico_all' AND a.metrica='FAT'))))
  OR (cardinality(f.suppliers)>0 AND (upper(categoria)=ANY(f.suppliers)
   OR ('1119'=ANY(f.suppliers) AND categoria IN ('1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO'))
   OR (categoria='1119_QUAKER_KEROCOCO' AND f.suppliers && ARRAY['1119_QUAKER','1119_KEROCOCO'])))))
 OR (metrica='VOL' AND ((cardinality(f.suppliers)=0 AND (categoria='pepsico_all' OR
  (categoria IN ('tonelada_elma','tonelada_foods') AND NOT EXISTS(SELECT 1 FROM all_targets a WHERE a.code=t.code AND a.categoria='pepsico_all' AND a.metrica='VOL'))))
  OR (cardinality(f.suppliers)>0 AND categoria=CASE
   WHEN f.suppliers <@ ARRAY['707','708','752'] THEN 'tonelada_elma'
   WHEN f.suppliers <@ ARRAY['1119','1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO','1119_QUAKER','1119_KEROCOCO'] THEN 'tonelada_foods' ELSE 'pepsico_all' END)))
 OR (metrica='POS' AND categoria=CASE WHEN cardinality(f.suppliers)=0 THEN 'pepsico_all'
  WHEN cardinality(f.suppliers)=1 THEN CASE f.suppliers[1] WHEN '1119' THEN 'total_foods'
   WHEN '1119_QUAKER' THEN '1119_QUAKER_KEROCOCO' WHEN '1119_KEROCOCO' THEN '1119_QUAKER_KEROCOCO' ELSE f.suppliers[1] END ELSE '__nao_aplicavel__' END)
 OR (metrica='MIX' AND cardinality(f.categories)=0 AND (cardinality(f.suppliers)=0
  OR (categoria='mix_salty' AND f.suppliers @> ARRAY['707','708','752'])
  OR (categoria='mix_foods' AND ('1119'=ANY(f.suppliers) OR f.suppliers @> ARRAY['1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO']))))
)
SELECT coalesce(jsonb_agg(jsonb_build_object('nivel','vendedor','codigo',code,'vendedor_nome',name,'supervisor_codigo',parent,
 'categoria',categoria,'metrica',metrica,'valor',value,'meta_original',original,'sem_base',value IS NULL,
 'reatribuida',true,'pendente',code='__PENDENTE__') ORDER BY code,categoria,metrica),'[]') FROM targets
$$;
REVOKE ALL ON FUNCTION private.evolution_attributed_targets(integer,integer,jsonb) FROM PUBLIC,anon,authenticated;

