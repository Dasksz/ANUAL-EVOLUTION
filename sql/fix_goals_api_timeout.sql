-- Avoid recalculating an identical unfiltered quarter.
BEGIN;
CREATE OR REPLACE FUNCTION private.evolution_goals_targets(p_ano integer,p_mes integer,p_filiais text[] DEFAULT ARRAY[]::text[], p_fornecedores text[] DEFAULT ARRAY[]::text[], p_supervisores text[] DEFAULT ARRAY[]::text[], p_vendedores text[] DEFAULT ARRAY[]::text[], p_categorias text[] DEFAULT ARRAY[]::text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_temp AS $$
DECLARE full_base jsonb; scoped_base jsonb; result jsonb;
BEGIN
 PERFORM private.evolution_assert_approved();
 full_base:=private.evolution_goals_base(p_ano,p_mes);
 IF coalesce(cardinality(p_filiais),0)=0 AND coalesce(cardinality(p_fornecedores),0)=0
 AND coalesce(cardinality(p_supervisores),0)=0 AND coalesce(cardinality(p_vendedores),0)=0
 AND coalesce(cardinality(p_categorias),0)=0 THEN
  scoped_base:=full_base;
 ELSE
  scoped_base:=private.evolution_goals_base(p_ano,p_mes,p_filiais,p_fornecedores,p_supervisores,p_vendedores,p_categorias);
 END IF;
 WITH all_sellers AS (SELECT value s FROM jsonb_array_elements(full_base->'sellers')),
 selected AS (SELECT value s FROM jsonb_array_elements(scoped_base->'sellers')),
 metas AS (
 SELECT DISTINCT ON (dv.codigo,m.categoria,m.metrica) m.*,dv.codigo code,dv.nome seller_name,
 private.evolution_goals_target_field(m.categoria,m.metrica) field
 FROM public.farol_metas_current m JOIN public.dim_vendedores dv ON
 ((m.codusur IS NOT NULL AND dv.codigo=m.codusur) OR (m.codusur IS NULL AND upper(trim(dv.nome))=upper(trim(m.vendedor_nome))))
 WHERE m.ano=p_ano AND m.mes=p_mes AND upper(dv.nome) NOT LIKE 'INATIVOS%'
 ORDER BY dv.codigo,m.categoria,m.metrica,m.updated_at DESC,m.id
 ), weights AS (
 SELECT m.*,a.s all_s,s.s scoped_s,
 CASE WHEN coalesce((a.s->>m.field)::numeric,0)>0 THEN
 least(1,greatest(0,coalesce((s.s->>m.field)::numeric,0)/(a.s->>m.field)::numeric))
 WHEN coalesce(cardinality(private.evolution_goals_values(p_filiais)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_supervisores)),0)=0
 AND private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores)) THEN 1
 WHEN a.s IS NULL AND 'SEM SUPERVISOR'=ANY(private.evolution_goals_values(p_supervisores)) AND coalesce(cardinality(p_filiais),0)=0 AND coalesce(cardinality(p_fornecedores),0)=0 AND coalesce(cardinality(p_categorias),0)=0 THEN 1
 WHEN s.s IS NOT NULL AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0 THEN 1 ELSE 0 END factor
 FROM metas m LEFT JOIN all_sellers a ON a.s->>'codusur'=m.code
 LEFT JOIN selected s ON s.s->>'codusur'=m.code
 WHERE private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores))
 ), allowed AS (
 SELECT w.* FROM weights w WHERE factor>0 AND
 (coalesce(cardinality(p_fornecedores),0)=0 OR
 (w.categoria IN ('pepsico_all','pedev','mix_salty','mix_foods','total_elma','total_foods','tonelada_elma','tonelada_foods')) OR
 w.categoria=ANY(p_fornecedores) OR ('1119'=ANY(p_fornecedores) AND w.categoria LIKE '1119_%') OR
 (w.categoria='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO']))
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'ano',ano,'mes',mes,'codusur',code,'vendedor_nome',seller_name,
 'categoria',categoria,'metrica',metrica,'valor_ajuste',CASE WHEN metrica IN ('POS','MIX') THEN round(valor_ajuste*factor) ELSE valor_ajuste*factor END,
 'source_value',valor_ajuste,'scope_factor',factor)), '[]'::jsonb) INTO result FROM allowed;
 RETURN result;
END;$$;

-- PostgREST applies these per-RPC limits before starting the statement.
ALTER FUNCTION public.get_metas_anuais_chart_multi(integer,integer,text[],text[],text[],text[],text[]) SET statement_timeout TO '55s';
ALTER FUNCTION public.get_metas_base_comparativo_multi(integer,integer,text[],text[],text[],text[],text[]) SET statement_timeout TO '55s';
ALTER FUNCTION public.get_metas_people_multi(integer,integer,text[],text[],text[],text[],text[]) SET statement_timeout TO '55s';
NOTIFY pgrst, 'reload schema';
COMMIT;
