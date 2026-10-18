-- Spreadsheet is authoritative. Hierarchy rows are separate from legacy seller rows.
CREATE TABLE IF NOT EXISTS private.metas_import_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ano integer NOT NULL, mes integer NOT NULL CHECK(mes BETWEEN 1 AND 12),
 imported_at timestamptz NOT NULL DEFAULT now(), imported_by uuid, payload jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS private.metas_planilha (
 ano integer NOT NULL, mes integer NOT NULL CHECK(mes BETWEEN 1 AND 12),
 nivel text NOT NULL CHECK(nivel IN ('vendedor','supervisor','empresa')),
 codigo_entidade text NOT NULL, nome text NOT NULL, supervisor_codigo text,
 categoria text NOT NULL, metrica text NOT NULL CHECK(metrica IN ('FAT','VOL','POS','MIX')),
 valor numeric NOT NULL CHECK(valor >= 0), origem jsonb NOT NULL,
 batch_id uuid NOT NULL REFERENCES private.metas_import_batches(id),
 PRIMARY KEY(ano,mes,nivel,codigo_entidade,categoria,metrica)
);
ALTER TABLE private.metas_import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.metas_planilha ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.metas_import_batches,private.metas_planilha FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.evolution_seller_code(code text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
 SELECT CASE code WHEN '1001' THEN 'AMERICANAS' WHEN '53' THEN 'BALCAO_SP' ELSE code END
$$;
REVOKE ALL ON FUNCTION private.evolution_seller_code(text) FROM PUBLIC,anon,authenticated;

-- The internal writer is separate so rollback fixtures can test the exact import without impersonating a user.
CREATE OR REPLACE FUNCTION private.evolution_import_targets(items jsonb) RETURNS uuid
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE y integer; m integer; batch uuid; item jsonb; code text;
BEGIN
 IF jsonb_typeof(items) IS DISTINCT FROM 'array' OR jsonb_array_length(items)=0 THEN RAISE EXCEPTION 'Planilha vazia.'; END IF;
 y:=(items->0->>'ano')::integer; m:=(items->0->>'mes')::integer;
 IF y NOT BETWEEN 2000 AND 2100 OR m NOT BETWEEN 1 AND 12 OR y IS NULL OR m IS NULL THEN RAISE EXCEPTION 'Período inválido.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(items) e WHERE
    (e->>'ano')::integer IS DISTINCT FROM y OR (e->>'mes')::integer IS DISTINCT FROM m
    OR coalesce(e->>'nivel','') NOT IN ('vendedor','supervisor','empresa')
    OR nullif(trim(e->>'codigo_entidade'),'') IS NULL OR nullif(trim(e->>'vendedor_nome'),'') IS NULL
    OR coalesce(e->>'metrica','') NOT IN ('FAT','VOL','POS','MIX')
    OR coalesce(e->>'categoria','') NOT IN ('total_elma','total_foods','707','708','752','1119_TODDYNHO','1119_TODDY','1119_QUAKER_KEROCOCO','tonelada_elma','tonelada_foods','mix_salty','mix_foods','pepsico_all','pedev')
    OR (e->>'valor_ajuste')::numeric IS NULL OR (e->>'valor_ajuste')::numeric < 0
    OR e->>'valor_ajuste' IN ('NaN','Infinity','-Infinity')
    OR jsonb_typeof(e->'origem') IS DISTINCT FROM 'array') THEN RAISE EXCEPTION 'Registro de meta inválido; nenhuma alteração foi salva.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(items) e GROUP BY e->>'nivel',e->>'codigo_entidade',e->>'categoria',e->>'metrica' HAVING count(*)>1) THEN RAISE EXCEPTION 'Código e indicador duplicados; agregue as carteiras antes de importar.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(items) e GROUP BY e->>'nivel',e->>'codigo_entidade' HAVING count(*)<>24) THEN RAISE EXCEPTION 'Planilha incompleta: cada vendedor, supervisor e empresa deve conter os 24 indicadores do modelo, incluindo auditoria PDEV.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(items) e WHERE jsonb_array_length(e->'origem')=0 OR
  (e->>'metrica' IN ('POS','MIX') AND (e->>'valor_ajuste')::numeric<>trunc((e->>'valor_ajuste')::numeric))) THEN RAISE EXCEPTION 'Origem ausente ou meta de clientes fracionada.'; END IF;
 IF (SELECT count(DISTINCT e->>'codigo_entidade') FROM jsonb_array_elements(items) e WHERE e->>'nivel'='empresa')<>1 THEN RAISE EXCEPTION 'A planilha deve conter uma única linha GERAL da empresa.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(items) e WHERE e->>'nivel'='empresa' AND e->>'categoria'='pepsico_all' AND e->>'metrica'='POS') THEN RAISE EXCEPTION 'Falta a meta de positivação GERAL da empresa.'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(items) e WHERE e->>'nivel'='vendedor' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(items) s WHERE s->>'nivel'='supervisor' AND s->>'codigo_entidade'=e->>'supervisor_codigo')) THEN RAISE EXCEPTION 'Vendedor sem subtotal de supervisor na planilha.'; END IF;
 PERFORM pg_advisory_xact_lock(20261017,y*100+m);
 INSERT INTO private.metas_import_batches(ano,mes,imported_by,payload) VALUES(y,m,auth.uid(),items) RETURNING id INTO batch;
 DELETE FROM private.metas_planilha WHERE ano=y AND mes=m;
 -- Replace the entire imported month so reassigned/absent sellers cannot keep obsolete targets.
 DELETE FROM public.metas_sv WHERE ano=y AND mes=m;
 FOR item IN SELECT value FROM jsonb_array_elements(items) LOOP
   code:=item->>'codigo_entidade';
   INSERT INTO private.metas_planilha VALUES(y,m,item->>'nivel',code,item->>'vendedor_nome',item->>'supervisor_codigo',item->>'categoria',item->>'metrica',(item->>'valor_ajuste')::numeric,item->'origem',batch);
   IF item->>'nivel'='vendedor' THEN
    INSERT INTO public.metas_sv(ano,mes,codusur,vendedor_nome,categoria,metrica,valor_ajuste)
    VALUES(y,m,private.evolution_seller_code(code),item->>'vendedor_nome',item->>'categoria',item->>'metrica',(item->>'valor_ajuste')::numeric);
   END IF;
 END LOOP;
 RETURN batch;
END $$;
REVOKE ALL ON FUNCTION private.evolution_import_targets(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.import_metas_planilha(p_metas_json jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM private.evolution_assert_approved();
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND status='aprovado') THEN RAISE EXCEPTION 'Acesso negado.'; END IF;
 RETURN jsonb_build_object('batch_id',private.evolution_import_targets(p_metas_json));
END $$;
REVOKE ALL ON FUNCTION public.import_metas_planilha(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.import_metas_planilha(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_metas_planilha(p_ano integer,p_mes integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM private.evolution_assert_approved();
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM private.metas_planilha t WHERE ano=p_ano AND mes=p_mes),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.get_metas_planilha(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_metas_planilha(integer,integer) TO authenticated;

-- Change only the goals readers; Farol keeps its independent budget.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid,pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='private' AND p.proname IN ('evolution_goals_targets','evolution_goals_chart'))
 OR (n.nspname='public' AND p.proname='get_metas_sv') LOOP
  EXECUTE replace(f.def,'public.farol_metas_current','public.metas_sv');
 END LOOP;
END $$;

-- Keep the legacy manual editor code-aware; a manual edit also updates the imported leaf.
CREATE OR REPLACE FUNCTION public.upsert_metas(p_metas_json jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE e jsonb; c text;
BEGIN
 PERFORM private.evolution_assert_approved();
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND status='aprovado') THEN RAISE EXCEPTION 'Acesso negado.'; END IF;
 FOR e IN SELECT value FROM jsonb_array_elements(p_metas_json) LOOP
  c:=private.evolution_seller_code(e->>'codusur');
  INSERT INTO public.metas_sv(ano,mes,codusur,vendedor_nome,categoria,metrica,valor_ajuste)
  VALUES((e->>'ano')::integer,(e->>'mes')::integer,c,e->>'vendedor_nome',e->>'categoria',e->>'metrica',(e->>'valor_ajuste')::numeric)
  ON CONFLICT(ano,mes,vendedor_nome,categoria,metrica) DO UPDATE SET codusur=coalesce(excluded.codusur,metas_sv.codusur),valor_ajuste=excluded.valor_ajuste,updated_at=now();
  UPDATE private.metas_planilha SET valor=(e->>'valor_ajuste')::numeric
   WHERE ano=(e->>'ano')::integer AND mes=(e->>'mes')::integer AND nivel='vendedor'
   AND private.evolution_seller_code(codigo_entidade)=c AND categoria=e->>'categoria' AND metrica=e->>'metrica';
 END LOOP;
END $$;
