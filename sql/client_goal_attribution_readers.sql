CREATE FUNCTION private.evolution_attributed_targets(y integer,mo integer,f jsonb) RETURNS jsonb
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
 SELECT q.* FROM private.evolution_client_goal_ownership q CROSS JOIN filters f
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

-- The existing company/supervisor calculations remain authoritative; seller reads use the fixed client quotas.
ALTER FUNCTION private.evolution_dashboard_targets(integer,integer,jsonb) RENAME TO evolution_dashboard_targets_official;
CREATE FUNCTION private.evolution_dashboard_targets(y integer,mo integer,f jsonb) RETURNS jsonb
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM private.evolution_assert_approved();
 PERFORM private.evolution_sync_meta_period(y,mo);
 IF f->>'force_level'='vendedor' OR jsonb_array_length(coalesce(f->'p_vendedor','[]'))>0 THEN
  RETURN private.evolution_attributed_targets(y,mo,f);
 END IF;
 RETURN private.evolution_dashboard_targets_official(y,mo,f);
END $$;
REVOKE ALL ON FUNCTION private.evolution_dashboard_targets(integer,integer,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.evolution_goals_targets(
 p_ano integer,p_mes integer,p_filiais text[] DEFAULT '{}',p_fornecedores text[] DEFAULT '{}',
 p_supervisores text[] DEFAULT '{}',p_vendedores text[] DEFAULT '{}',p_categorias text[] DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 SELECT coalesce(jsonb_agg(jsonb_build_object('ano',p_ano,'mes',p_mes,'codusur',e->>'codigo',
  'categoria',e->>'categoria','metrica',e->>'metrica','valor_ajuste',e->'valor','source_value',e->'meta_original',
  'scope_factor',CASE WHEN (e->>'meta_original')::numeric>0 THEN (e->>'valor')::numeric/(e->>'meta_original')::numeric ELSE 1 END,
  'vendedor_nome',e->>'vendedor_nome','supervisor_codigo',e->>'supervisor_codigo','reatribuida',true)), '[]') INTO result
 FROM jsonb_array_elements(private.evolution_dashboard_targets(p_ano,p_mes,
  jsonb_build_object('force_level','vendedor','all_metrics',true,'p_filial',p_filiais,'p_fornecedor',p_fornecedores,
  'p_supervisor',p_supervisores,'p_vendedor',p_vendedores,'p_categoria',p_categorias))) e;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.get_metas_sv(p_ano integer,p_mes integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM private.evolution_assert_approved();
 RETURN private.evolution_goals_targets(p_ano,p_mes);
END $$;

CREATE OR REPLACE FUNCTION public.get_metas_base_comparativo_multi(
 p_ano integer,p_mes integer,p_filiais text[] DEFAULT '{}',p_fornecedores text[] DEFAULT '{}',
 p_supervisores text[] DEFAULT '{}',p_vendedores text[] DEFAULT '{}',p_categorias text[] DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET statement_timeout='55s' SET work_mem='90MB' AS $$
DECLARE b jsonb; t jsonb; growth numeric;
BEGIN
 PERFORM private.evolution_assert_approved();
 p_filiais:=private.evolution_goals_values(p_filiais);p_fornecedores:=private.evolution_goals_values(p_fornecedores);
 p_supervisores:=private.evolution_goals_values(p_supervisores);p_vendedores:=private.evolution_goals_values(p_vendedores);
 p_categorias:=private.evolution_goals_values(p_categorias);
 IF cardinality(p_filiais)>0 AND NOT EXISTS(SELECT 1 FROM (SELECT DISTINCT filial FROM public.data_summary_current WHERE filial IS NOT NULL)d WHERE upper(d.filial)<>ALL(p_filiais)) THEN p_filiais:='{}'; END IF;
 IF p_fornecedores @> ARRAY['707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO'] THEN p_fornecedores:='{}'; END IF;
 b:=private.evolution_goals_base(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 t:=private.evolution_goals_targets(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 SELECT percentual INTO growth FROM metas_crescimento WHERE ano=p_ano;
 WITH existing AS (SELECT value s FROM jsonb_array_elements(b->'sellers')),
 owners AS (SELECT DISTINCT m->>'codusur' code,m->>'vendedor_nome' name,m->>'supervisor_codigo' parent FROM jsonb_array_elements(t)m),
 current_parents AS (SELECT code,max(parent) parent FROM owners GROUP BY code),
 all_sellers AS (
  SELECT s FROM existing UNION ALL SELECT jsonb_build_object('codusur',code,'vendedor_nome',name)
  FROM owners o WHERE NOT EXISTS(SELECT 1 FROM existing e WHERE e.s->>'codusur'=o.code)
 ) SELECT jsonb_set(b,'{sellers}',coalesce(jsonb_agg(s || jsonb_build_object(
  'supervisor_codigo',coalesce(p.parent,s->>'supervisor_codigo',''),
  'supervisor_nome',CASE WHEN s->>'codusur'='__PENDENTE__' THEN 'PENDENTES DE ATRIBUIÇÃO'
   ELSE coalesce(d.nome,s->>'supervisor_nome','SEM SUPERVISOR') END) ORDER BY s->>'vendedor_nome'),'[]')) INTO b
 FROM all_sellers a LEFT JOIN current_parents p ON p.code=a.s->>'codusur' LEFT JOIN dim_supervisores d ON d.codigo=p.parent;
 RETURN b||jsonb_build_object('metas',t,'growth',growth,'scope_version',2,'attribution_version',1,
  'attribution',public.get_meta_attribution_status(p_ano,p_mes));
END $$;

-- Append status to the dashboard without changing its existing response fields.
ALTER FUNCTION public.get_dashboard_metas(jsonb) RENAME TO evolution_dashboard_metas_original;
ALTER FUNCTION public.evolution_dashboard_metas_original(jsonb) SET SCHEMA private;
REVOKE ALL ON FUNCTION private.evolution_dashboard_metas_original(jsonb) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.get_dashboard_metas(p_filters jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET statement_timeout='55s' AS $$
DECLARE r jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 r:=private.evolution_dashboard_metas_original(p_filters);
 RETURN r||jsonb_build_object('attribution',public.get_meta_attribution_status((r->>'ano')::integer));
END $$;
REVOKE ALL ON FUNCTION public.get_dashboard_metas(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_metas(jsonb) TO authenticated;

-- Record bindings immediately at import time, before the next cadastro can change ownership.
ALTER FUNCTION private.evolution_import_targets(jsonb) RENAME TO evolution_import_targets_original;
CREATE FUNCTION private.evolution_import_targets(items jsonb) RETURNS uuid
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE batch uuid;
BEGIN
 batch:=private.evolution_import_targets_original(items);
 PERFORM private.evolution_sync_meta_period((items->0->>'ano')::integer,(items->0->>'mes')::integer);
 RETURN batch;
END $$;
REVOKE ALL ON FUNCTION private.evolution_import_targets(jsonb) FROM PUBLIC,anon,authenticated;
