-- Alinha a leitura da meta de Positivação Geral ao DASHBOARD-PROMOTORES.
-- Regra de origem: a meta geral de positivação vem da categoria consolidada "pepsico_all",
-- e não da soma de total_elma + total_foods.
-- Também ignora registros de metas cujo vendedor não existe em dim_vendedores,
-- evitando que linhas agregadas/residuais contaminem o total.

DO $$
DECLARE
    v_oid oid;
    v_def text;
    v_old text;
    v_new text;
BEGIN
    SELECT p.oid
      INTO v_oid
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'get_metas_anuais_chart'
       AND pg_get_function_identity_arguments(p.oid) LIKE '%p_filial%'
     LIMIT 1;

    IF v_oid IS NULL THEN
        RAISE EXCEPTION 'Função public.get_metas_anuais_chart com filtros de filial/fornecedor não encontrada';
    END IF;

    v_def := pg_get_functiondef(v_oid);

    v_old := $old$
SUM(CASE WHEN m.metrica = 'POS' AND (
                (p_fornecedor = 'Todos' AND m.categoria IN ('total_elma', 'total_foods')) OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_pos_geral
$old$;

    v_new := $new$
SUM(CASE WHEN m.metrica = 'POS' AND (
                (p_fornecedor = 'Todos' AND m.categoria = 'pepsico_all') OR
                (p_fornecedor != 'Todos' AND (m.categoria = p_fornecedor OR (p_fornecedor IN ('1119_QUAKER', '1119_KEROCOCO', 'QUAKER', 'KEROCOCO') AND m.categoria = '1119_QUAKER_KEROCOCO') OR (p_fornecedor = '1119' AND (m.categoria = '1119' OR m.categoria LIKE '1119_%'))))
            ) THEN m.valor_ajuste ELSE 0 END) as meta_pos_geral
$new$;

    IF position(v_old in v_def) = 0 THEN
        RAISE EXCEPTION 'Bloco meta_pos_geral esperado não encontrado';
    END IF;
    v_def := replace(v_def, v_old, v_new);

    v_old := $old$
FROM public.metas_sv m
        WHERE m.ano = p_ano
          AND (p_codusur IS NULL OR p_codusur = '' OR m.vendedor_nome = p_codusur OR m.vendedor_nome IN (SELECT nome FROM public.dim_vendedores WHERE codigo = p_codusur))
$old$;

    v_new := $new$
FROM public.metas_sv m
        WHERE m.ano = p_ano
          AND EXISTS (
              SELECT 1
              FROM public.dim_vendedores dv_valid
              WHERE UPPER(TRIM(dv_valid.nome)) = UPPER(TRIM(m.vendedor_nome))
          )
          AND (p_codusur IS NULL OR p_codusur = '' OR m.vendedor_nome = p_codusur OR m.vendedor_nome IN (SELECT nome FROM public.dim_vendedores WHERE codigo = p_codusur))
$new$;

    IF position(v_old in v_def) = 0 THEN
        RAISE EXCEPTION 'Bloco metas_salvas esperado não encontrado';
    END IF;
    v_def := replace(v_def, v_old, v_new);

    EXECUTE v_def;
END
$$;
