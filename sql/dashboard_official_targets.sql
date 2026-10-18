CREATE OR REPLACE VIEW private.evolution_official_targets AS
 SELECT t.ano,t.mes,t.nivel,t.codigo_entidade,t.nome,t.supervisor_codigo,t.categoria,t.metrica,t.valor FROM private.metas_planilha t
 UNION ALL
 SELECT m.ano,m.mes,'vendedor',coalesce(m.codusur,d.codigo),m.vendedor_nome,NULL::text,m.categoria,m.metrica,m.valor_ajuste
 FROM public.metas_sv m LEFT JOIN public.dim_vendedores d ON m.codusur IS NULL AND upper(trim(d.nome))=upper(trim(m.vendedor_nome))
 WHERE NOT EXISTS(SELECT 1 FROM private.metas_planilha t WHERE t.ano=m.ano AND t.mes=m.mes);
REVOKE ALL ON private.evolution_official_targets FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.evolution_target_contains(cat text,supplier text,brand text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT CASE
 WHEN cat='pepsico_all' THEN true
 WHEN cat IN ('total_elma','tonelada_elma','mix_salty') THEN supplier IN ('707','708','752')
 WHEN cat IN ('total_foods','tonelada_foods','mix_foods','1119') THEN supplier LIKE '1119%'
 WHEN cat='1119_QUAKER_KEROCOCO' THEN supplier='1119_QUAKER_KEROCOCO' OR brand IN ('QUAKER','KEROCOCO')
 WHEN cat='1119_QUAKER' THEN brand='QUAKER'
 WHEN cat='1119_KEROCOCO' THEN brand='KEROCOCO'
 WHEN cat='1119_TODDY' THEN supplier=cat OR brand='TODDY'
 WHEN cat='1119_TODDYNHO' THEN supplier=cat OR brand='TODDYNHO'
 ELSE supplier=cat END
$$;
REVOKE ALL ON FUNCTION private.evolution_target_contains(text,text,text) FROM PUBLIC,anon,authenticated;

-- One quota per client/month before any dimensional filter. Overlapping category selections
-- use bool_or on joint purchase rows, so a client quota can be counted only once in a union.
CREATE OR REPLACE FUNCTION private.evolution_dashboard_targets(y integer,mo integer,f jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=public,pg_temp SET work_mem='90MB' AS $$
WITH filters AS (
 SELECT ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_vendedor','[]'))) sellers,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_supervisor','[]'))) supervisors,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_fornecedor','[]'))) suppliers,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_categoria','[]'))) categories,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_filial','[]'))) branches,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_cidade','[]'))) cities,
 ARRAY(SELECT upper(value) FROM jsonb_array_elements_text(coalesce(f->'p_rede','[]'))) networks
), owners AS MATERIALIZED (
 SELECT t.*,coalesce(t.supervisor_codigo,s.codsupervisor) parent
 FROM private.evolution_official_targets t
 LEFT JOIN (
  SELECT DISTINCT ON (codusur) codusur,codsupervisor FROM public.data_summary_current
  WHERE ano BETWEEN y-1 AND y AND ano*12+mes<=y*12+mo AND codsupervisor IS NOT NULL
  GROUP BY codusur,codsupervisor,ano,mes ORDER BY codusur,ano DESC,mes DESC,count(*) DESC,codsupervisor
 ) s ON private.evolution_seller_code(s.codusur)=private.evolution_seller_code(t.codigo_entidade)
 WHERE t.ano=y AND t.mes=mo AND t.categoria<>'pedev'
), chosen AS MATERIALIZED (
 SELECT t.* FROM owners t CROSS JOIN filters f
 WHERE CASE
 WHEN $3->>'force_level'='vendedor' THEN t.nivel='vendedor' AND (cardinality(f.sellers)=0 OR private.evolution_goals_match(private.evolution_seller_code(t.codigo_entidade),t.nome,f.sellers))
  AND (cardinality(f.supervisors)=0 OR upper(t.parent)=ANY(f.supervisors) OR EXISTS(SELECT 1 FROM public.dim_supervisores d WHERE d.codigo=t.parent AND upper(trim(d.nome))=ANY(f.supervisors)))
 WHEN cardinality(f.sellers)>0 THEN t.nivel='vendedor' AND private.evolution_goals_match(private.evolution_seller_code(t.codigo_entidade),t.nome,f.sellers)
 WHEN cardinality(f.supervisors)>0 THEN
  (t.nivel='supervisor' AND private.evolution_goals_match(t.codigo_entidade,t.nome,f.supervisors)) OR
  (t.nivel='vendedor' AND (upper(t.parent)=ANY(f.supervisors) OR EXISTS(SELECT 1 FROM public.dim_supervisores d WHERE d.codigo=t.parent AND upper(trim(d.nome))=ANY(f.supervisors)))
   AND NOT EXISTS(SELECT 1 FROM owners p WHERE p.nivel='supervisor' AND p.codigo_entidade=t.parent AND p.categoria=t.categoria AND p.metrica=t.metrica))
 ELSE t.nivel=CASE WHEN EXISTS(SELECT 1 FROM owners p WHERE p.nivel='empresa' AND p.categoria=t.categoria AND p.metrica=t.metrica) THEN 'empresa' ELSE 'vendedor' END END
 AND (cardinality(f.sellers)=0 OR cardinality(f.supervisors)=0 OR upper(t.parent)=ANY(f.supervisors)
  OR EXISTS(SELECT 1 FROM public.dim_supervisores d WHERE d.codigo=t.parent AND upper(trim(d.nome))=ANY(f.supervisors)))
), targets AS MATERIALIZED (
 SELECT row_number() OVER(ORDER BY nivel,codigo_entidade,categoria,metrica) id,t.*,
 CASE WHEN t.nivel='vendedor' THEN ARRAY[private.evolution_seller_code(t.codigo_entidade)]
 WHEN t.nivel='supervisor' THEN ARRAY(SELECT DISTINCT private.evolution_seller_code(child.codigo_entidade) FROM owners child WHERE child.nivel='vendedor' AND child.parent=t.codigo_entidade)
 ELSE NULL::text[] END seller_codes,
 CASE metrica WHEN 'FAT' THEN 100 WHEN 'VOL' THEN 1000 ELSE 1 END scale
 FROM chosen t CROSS JOIN filters f
 WHERE $3->>'all_metrics'='true' OR (metrica='FAT' AND ((cardinality(f.suppliers)=0 AND (categoria='pepsico_all' OR (categoria IN ('707','708','752','1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO') AND NOT EXISTS(SELECT 1 FROM chosen g WHERE g.nivel=t.nivel AND g.codigo_entidade=t.codigo_entidade AND g.categoria='pepsico_all' AND g.metrica=t.metrica)))) OR (cardinality(f.suppliers)>0 AND (upper(categoria)=ANY(f.suppliers) OR ('1119'=ANY(f.suppliers) AND categoria IN ('1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO')) OR (categoria='1119_QUAKER_KEROCOCO' AND f.suppliers && ARRAY['1119_QUAKER','1119_KEROCOCO'])))))
 OR (metrica='VOL' AND cardinality(f.suppliers)=0 AND categoria IN ('tonelada_elma','tonelada_foods') AND NOT EXISTS(SELECT 1 FROM chosen g WHERE g.nivel=t.nivel AND g.codigo_entidade=t.codigo_entidade AND g.categoria='pepsico_all' AND g.metrica='VOL'))
 OR (metrica='VOL' AND categoria=CASE WHEN cardinality(f.suppliers)=0 THEN 'pepsico_all' WHEN f.suppliers <@ ARRAY['707','708','752'] THEN 'tonelada_elma' WHEN f.suppliers <@ ARRAY['1119','1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO','1119_QUAKER','1119_KEROCOCO'] THEN 'tonelada_foods' ELSE 'pepsico_all' END)
 OR (metrica='POS' AND categoria=CASE WHEN cardinality(f.suppliers)=0 THEN 'pepsico_all' WHEN cardinality(f.suppliers)=1 THEN CASE f.suppliers[1] WHEN '1119' THEN 'total_foods' WHEN '1119_QUAKER' THEN '1119_QUAKER_KEROCOCO' WHEN '1119_KEROCOCO' THEN '1119_QUAKER_KEROCOCO' ELSE f.suppliers[1] END ELSE '__inapplicable__' END)
 OR (metrica='MIX' AND categoria IN ('mix_salty','mix_foods') AND cardinality(f.categories)=0 AND (cardinality(f.suppliers)=0 OR (categoria='mix_salty' AND f.suppliers @> ARRAY['707','708','752']) OR (categoria='mix_foods' AND ('1119'=ANY(f.suppliers) OR f.suppliers @> ARRAY['1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO']))))
), brands AS MATERIALIZED (
 SELECT categoria_produto,min(upper(mix_marca)) brand FROM public.dim_produtos GROUP BY categoria_produto
), raw AS MATERIALIZED (
 SELECT d.*,coalesce(b.brand,upper(d.categoria_produto)) brand,
  private.evolution_seller_code(d.codusur) seller
 FROM public.data_summary_current d LEFT JOIN brands b USING(categoria_produto)
 WHERE d.ano*12+d.mes BETWEEN y*12+mo-3 AND y*12+mo-1 AND d.ano BETWEEN y-1 AND y
 AND EXISTS(SELECT 1 FROM filters f WHERE cardinality(f.branches)>0 OR cardinality(f.categories)>0 OR cardinality(f.cities)>0 OR cardinality(f.networks)>0 OR cardinality(f.suppliers)>0)
 AND d.tipovenda NOT IN ('5','11')
), profiles0 AS MATERIALIZED (
 SELECT t.id,CASE WHEN t.metrica IN ('POS','MIX') THEN concat(r.ano,'/',r.mes,'/',r.codcli) ELSE r.id::text END profile,
 max(upper(r.cidade)) city,max(upper(coalesce(nullif(trim(r.ramo),''),'S/ REDE'))) network,
 bool_or((cardinality(f.branches)=0 OR upper(r.filial)=ANY(f.branches))
  AND (cardinality(f.categories)=0 OR upper(r.categoria_produto)=ANY(f.categories) OR r.brand=ANY(f.categories))
  AND (cardinality(f.suppliers)=0 OR EXISTS(SELECT 1 FROM unnest(f.suppliers) q WHERE (CASE
 WHEN q='pepsico_all' THEN true
 WHEN q IN ('total_elma','tonelada_elma','mix_salty') THEN r.codfor IN ('707','708','752')
 WHEN q IN ('total_foods','tonelada_foods','mix_foods','1119') THEN r.codfor LIKE '1119%'
 WHEN q='1119_QUAKER_KEROCOCO' THEN r.codfor='1119_QUAKER_KEROCOCO' OR r.brand IN ('QUAKER','KEROCOCO')
 WHEN q='1119_QUAKER' THEN r.brand='QUAKER'
 WHEN q='1119_KEROCOCO' THEN r.brand='KEROCOCO'
 WHEN q='1119_TODDY' THEN r.codfor=q OR r.brand='TODDY'
 WHEN q='1119_TODDYNHO' THEN r.codfor=q OR r.brand='TODDYNHO'
 ELSE r.codfor=q END)))) edge_match,
 CASE t.metrica WHEN 'FAT' THEN sum(greatest(r.vlvenda,0)) WHEN 'VOL' THEN sum(greatest(r.peso,0)) ELSE 1 END weight,
 array_agg(DISTINCT r.brand) brands
 FROM targets t CROSS JOIN filters f JOIN raw r ON
  (t.nivel='empresa' OR r.seller=ANY(t.seller_codes))
  AND (CASE
 WHEN t.categoria='pepsico_all' THEN true
 WHEN t.categoria IN ('total_elma','tonelada_elma','mix_salty') THEN r.codfor IN ('707','708','752')
 WHEN t.categoria IN ('total_foods','tonelada_foods','mix_foods','1119') THEN r.codfor LIKE '1119%'
 WHEN t.categoria='1119_QUAKER_KEROCOCO' THEN r.codfor='1119_QUAKER_KEROCOCO' OR r.brand IN ('QUAKER','KEROCOCO')
 WHEN t.categoria='1119_QUAKER' THEN r.brand='QUAKER'
 WHEN t.categoria='1119_KEROCOCO' THEN r.brand='KEROCOCO'
 WHEN t.categoria='1119_TODDY' THEN r.codfor=t.categoria OR r.brand='TODDY'
 WHEN t.categoria='1119_TODDYNHO' THEN r.codfor=t.categoria OR r.brand='TODDYNHO'
 ELSE r.codfor=t.categoria END)
  AND ((t.metrica IN ('POS','MIX') AND r.vlvenda>0 AND r.codcli IS NOT NULL) OR (t.metrica IN ('FAT','VOL') AND r.tipovenda IN ('1','9')))
 WHERE cardinality(f.branches)>0 OR cardinality(f.categories)>0 OR cardinality(f.cities)>0 OR cardinality(f.networks)>0 OR cardinality(f.suppliers)>0
 GROUP BY t.id,t.metrica,CASE WHEN t.metrica IN ('POS','MIX') THEN concat(r.ano,'/',r.mes,'/',r.codcli) ELSE r.id::text END
), profiles AS MATERIALIZED (
 SELECT p.*,p.edge_match AND (cardinality(f.cities)=0 OR p.city=ANY(f.cities))
 AND (cardinality(f.networks)=0 OR p.network=ANY(f.networks) OR (f.networks && ARRAY['COM_RAMO','C/ REDE'] AND p.network<>'S/ REDE') OR (f.networks && ARRAY['SEM_RAMO','S/ REDE'] AND p.network='S/ REDE')) selected
 FROM profiles0 p JOIN targets t ON t.id=p.id CROSS JOIN filters f
 WHERE weight>0 AND (t.metrica<>'MIX' OR (t.categoria='mix_salty' AND p.brands @> ARRAY['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA']) OR (t.categoria='mix_foods' AND p.brands @> ARRAY['TODDYNHO','TODDY','QUAKER','KEROCOCO']))
), exact AS MATERIALIZED (
 SELECT p.*,round(t.valor*t.scale)*p.weight/sum(p.weight) OVER(PARTITION BY p.id) quota,t.valor,t.scale FROM profiles p JOIN targets t USING(id)
), ranked AS MATERIALIZED (
 SELECT *,row_number() OVER(PARTITION BY id ORDER BY quota-floor(quota) DESC,profile) rank,
 round(valor*scale)-sum(floor(quota)) OVER(PARTITION BY id) remainder FROM exact
), allocated AS MATERIALIZED (
 SELECT id,sum((floor(quota)+CASE WHEN rank<=remainder THEN 1 ELSE 0 END)/scale) FILTER(WHERE selected) value,count(*) n FROM ranked GROUP BY id
), result AS MATERIALIZED (
 SELECT t.*,
 CASE WHEN cardinality(f.branches)=0 AND cardinality(f.categories)=0 AND cardinality(f.cities)=0 AND cardinality(f.networks)=0
  AND (cardinality(f.suppliers)=0 OR upper(t.categoria)=ANY(f.suppliers)
   OR ('1119'=ANY(f.suppliers) AND t.categoria IN ('1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO','total_foods'))
   OR (t.categoria='total_elma' AND f.suppliers @> ARRAY['707','708','752'])
   OR (t.categoria='mix_salty' AND f.suppliers @> ARRAY['707','708','752']) OR (t.categoria='mix_foods' AND ('1119'=ANY(f.suppliers) OR f.suppliers @> ARRAY['1119_TODDY','1119_TODDYNHO','1119_QUAKER_KEROCOCO']))
   OR (t.categoria='tonelada_elma' AND f.suppliers @> ARRAY['707','708','752']) OR (t.categoria='tonelada_foods' AND '1119'=ANY(f.suppliers)))
  THEN t.valor WHEN a.n>0 THEN coalesce(a.value,0) WHEN t.valor=0 THEN 0 ELSE NULL END value
 FROM targets t LEFT JOIN allocated a USING(id) CROSS JOIN filters f
)
SELECT coalesce(jsonb_agg(jsonb_build_object('nivel',nivel,'codigo',codigo_entidade,'categoria',categoria,'metrica',metrica,'valor',value,'meta_original',valor,'sem_base',value IS NULL)),'[]'::jsonb) FROM result
$$;
REVOKE ALL ON FUNCTION private.evolution_dashboard_targets(integer,integer,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_dashboard_metas(p_filters jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp SET statement_timeout='55s' AS $$
DECLARE y integer; m integer; rows jsonb; output jsonb:='[]'; source text; fallback jsonb; f jsonb; annual jsonb; actual jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 y:=CASE WHEN coalesce(p_filters->>'p_ano','') ~ '^\d{4}$' THEN (p_filters->>'p_ano')::integer ELSE coalesce((SELECT max(ano) FROM public.data_summary),extract(year FROM current_date)::integer) END;
 f:=p_filters;
 -- Normalize nullable arrays before passing them to the allocation engine.
 SELECT coalesce(jsonb_object_agg(key,CASE WHEN value='null'::jsonb THEN '[]'::jsonb ELSE value END),'{}') INTO f FROM jsonb_each(f);
 IF (f->'p_fornecedor') @> '["707","708","752","1119_TODDYNHO","1119_TODDY","1119_QUAKER_KEROCOCO"]'::jsonb OR (f->'p_fornecedor') @> '["707","708","752","1119"]'::jsonb THEN
  f:=jsonb_set(f,'{p_fornecedor}','[]');
 END IF;
 -- Preserve the established annual-growth estimate only for dimensions supported by that calculation.
 IF jsonb_array_length(coalesce(f->'p_cidade','[]'))=0 AND jsonb_array_length(coalesce(f->'p_rede','[]'))=0 THEN
  annual:=private.evolution_goals_chart(y,12,
   ARRAY(SELECT jsonb_array_elements_text(coalesce(f->'p_filial','[]'))),
   ARRAY(SELECT jsonb_array_elements_text(coalesce(f->'p_fornecedor','[]'))),
   ARRAY(SELECT jsonb_array_elements_text(coalesce(f->'p_supervisor','[]'))),
   ARRAY(SELECT jsonb_array_elements_text(coalesce(f->'p_vendedor','[]'))),
   ARRAY(SELECT jsonb_array_elements_text(coalesce(f->'p_categoria','[]'))));
 END IF;
 FOR m IN 1..12 LOOP
  rows:='[]'::jsonb;
  IF EXISTS(SELECT 1 FROM private.evolution_official_targets WHERE ano=y AND mes=m) THEN
   IF annual IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(e || jsonb_build_object('valor',e->'valor_ajuste')),'[]') INTO rows FROM jsonb_array_elements(annual->'target_rows') e WHERE (e->>'mes')::integer=m;
   ELSE
    rows:=private.evolution_dashboard_targets(y,m,f);
   END IF;
  END IF;
  source:='planilha';
  IF rows='[]'::jsonb AND NOT EXISTS(SELECT 1 FROM private.evolution_official_targets WHERE ano=y AND mes=m) THEN
   source:='sem_meta';
   SELECT value INTO fallback FROM jsonb_array_elements(annual->'chart_data') WHERE (value->>'mes')::integer=m;
   IF annual->>'percentual_crescimento' IS NOT NULL AND m>coalesce((annual->>'mes_fechado')::integer,12) THEN
    source:='estimativa';
    rows:=jsonb_build_array(
     jsonb_build_object('metrica','FAT','categoria','pepsico_all','valor',fallback->'kpi_meta_estimada_fat'),
     jsonb_build_object('metrica','VOL','categoria','pepsico_all','valor',fallback->'kpi_meta_estimada_vol'),
     jsonb_build_object('metrica','POS','categoria','pepsico_all','valor',round((fallback->>'kpi_meta_estimada_pos')::numeric)));
    IF jsonb_array_length(coalesce(f->'p_categoria','[]'))=0 AND jsonb_array_length(coalesce(f->'p_fornecedor','[]'))=0 THEN
     rows:=rows||jsonb_build_array(
      jsonb_build_object('metrica','MIX','categoria','mix_salty','valor',round((fallback->>'kpi_meta_estimada_salty')::numeric)),
      jsonb_build_object('metrica','MIX','categoria','mix_foods','valor',round((fallback->>'kpi_meta_estimada_foods')::numeric)));
    END IF;
   END IF;
  END IF;
  output:=output||jsonb_build_array(jsonb_build_object('mes',m,'origem',source,'metas',rows));
 END LOOP;
 RETURN jsonb_build_object('ano',y,'chart_data',output,'regra','Rateio sobre os três meses anteriores; categorias sobrepostas contam cada cota de cliente uma vez.');
END $$;
REVOKE ALL ON FUNCTION public.get_dashboard_metas(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_dashboard_metas(jsonb) TO authenticated;
