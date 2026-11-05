BEGIN;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT id FROM public.profiles WHERE status='aprovado' LIMIT 1),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SET LOCAL statement_timeout='30s';
DO $$DECLARE f jsonb;before_data jsonb;after_data jsonb;statement text;checks integer:=0;BEGIN
 statement:='SELECT public.get_mix_salty_foods_data(p_ano:=p.p_ano,p_mes:=p.p_mes,p_cidade:=p.p_cidade,p_filial:=p.p_filial,p_supervisor:=p.p_supervisor,p_vendedor:=p.p_vendedor,p_fornecedor:=p.p_fornecedor,p_rede:=p.p_rede,p_produto:=p.p_produto,p_categoria:=p.p_categoria,p_tipovenda:=p.p_tipovenda)::jsonb FROM jsonb_to_record($1) AS p(p_ano text,p_mes text,p_cidade text[],p_filial text[],p_supervisor text[],p_vendedor text[],p_fornecedor text[],p_rede text[],p_produto text[],p_categoria text[],p_tipovenda text[])';
 FOR f IN SELECT value FROM jsonb_array_elements(jsonb_build_array(
  '{"p_ano":"2026"}'::jsonb,
  '{"p_ano":"2025"}'::jsonb,
  jsonb_build_object('p_ano','2026','p_supervisor',jsonb_build_array((SELECT nome FROM public.dim_supervisores WHERE codigo='21'))),
  jsonb_build_object('p_ano','2026','p_vendedor',jsonb_build_array((SELECT nome FROM public.dim_vendedores WHERE codigo='321'))),
  '{"p_ano":"2026","p_filial":["05","08"],"p_fornecedor":["707","708","752"],"p_tipovenda":["1","9"]}'::jsonb,
  '{"p_ano":"2026","p_categoria":["DORITOS"],"p_produto":["5919","6300"]}'::jsonb,
  '{"p_ano":"2026","p_cidade":["ILHEUS"],"p_rede":["S/ REDE"]}'::jsonb
 )) LOOP
  PERFORM set_config('enable_indexscan','off',true);
  PERFORM set_config('enable_indexonlyscan','off',true);
  PERFORM set_config('enable_bitmapscan','off',true);
  EXECUTE statement INTO before_data USING f;
  PERFORM set_config('enable_indexscan','on',true);
  PERFORM set_config('enable_indexonlyscan','on',true);
  PERFORM set_config('enable_bitmapscan','on',true);
  EXECUTE statement INTO after_data USING f;
  IF before_data IS DISTINCT FROM after_data THEN RAISE EXCEPTION 'Mix results changed for filters %',f;END IF;
  checks:=checks+1;
 END LOOP;
 PERFORM set_config('mix.parity_checks',checks::text,true);
END;$$;
SELECT current_setting('mix.parity_checks')::integer identical_filter_cases;
ROLLBACK;
