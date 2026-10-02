BEGIN;
DO $test$
DECLARE r jsonb; m jsonb; metric text; prev numeric; fixed numeric; dyn numeric;
BEGIN
r:=public.get_metas_anuais_chart(2026,NULL::text,NULL::text,10,'Todos','Todas','Todos');
FOR m IN SELECT value FROM jsonb_array_elements(r->'chart_data') LOOP
FOREACH metric IN ARRAY ARRAY['pos','salty','foods'] LOOP
prev:=(m->>('kpi_realizado_anterior_'||metric))::numeric;
fixed:=(m->>('kpi_meta_fixa_'||metric))::numeric;
dyn:=(m->>('kpi_meta_estimada_'||metric))::numeric;
IF (m->>'mes')::int<9 AND abs(fixed-prev*1.3)>0.0001 THEN RAISE EXCEPTION 'Wrong fixed monthly target % %',m->>'mes',metric; END IF;
IF (m->>'mes')::int>9 AND dyn+0.0001<prev*1.3 THEN RAISE EXCEPTION 'Future goal below baseline % %',m->>'mes',metric; END IF;
IF (m->>'mes')::int<=9 AND dyn IS DISTINCT FROM (m->>('kpi_realizado_atual_'||metric))::numeric THEN RAISE EXCEPTION 'Closed actual altered'; END IF;
END LOOP;
END LOOP;
IF (r->>'kpi_total_atual_pos')::int<>2548 OR (r->>'kpi_total_atual_foods')::int<>425 THEN RAISE EXCEPTION 'Annual unique KPI changed'; END IF;
END;
$test$;
DO $reserve$
DECLARE r jsonb; m jsonb; total_prev numeric:=0; total_plan numeric:=0; october numeric; seller text;
BEGIN
SELECT vendedor_nome INTO seller FROM public.metas_sv WHERE ano=2026 AND EXISTS (SELECT 1 FROM public.dim_vendedores d WHERE UPPER(TRIM(d.nome))=UPPER(TRIM(vendedor_nome))) LIMIT 1;
IF seller IS NULL THEN RAISE EXCEPTION 'No valid goal seller for regression'; END IF;
UPDATE public.metas_crescimento SET percentual=300 WHERE ano=2026;
INSERT INTO public.metas_sv(ano,mes,vendedor_nome,categoria,metrica,valor_ajuste) VALUES (2026,10,seller,'pepsico_all','POS',1000)
ON CONFLICT (ano,mes,vendedor_nome,categoria,metrica) DO UPDATE SET valor_ajuste=1000;
r:=public.get_metas_anuais_chart(2026,NULL::text,NULL::text,10,'Todos','Todas','Todos');
FOR m IN SELECT value FROM jsonb_array_elements(r->'chart_data') LOOP
total_prev:=total_prev+(m->>'kpi_realizado_anterior_pos')::numeric;
total_plan:=total_plan+(m->>'kpi_meta_estimada_pos')::numeric;
IF (m->>'mes')::int=10 THEN october:=(m->>'kpi_meta_estimada_pos')::numeric; END IF;
END LOOP;
IF october<>1000 THEN RAISE EXCEPTION 'Imported monthly override changed: %',october; END IF;
IF abs(total_plan-total_prev*4)>0.001 THEN RAISE EXCEPTION 'Reserved goal not deducted: plan %, target %',total_plan,total_prev*4; END IF;
END;
$reserve$;
ROLLBACK;
SELECT 'PASS: monthly baseline, unique annual counts, closed actuals and manual goal reservation' result;
