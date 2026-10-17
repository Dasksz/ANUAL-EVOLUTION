-- Align goal reads with the indexed summary source used by the main dashboard.
-- This keeps the goals filters on the same month/seller/customer grain while
-- avoiding repeated scans and joins over raw detailed and history sales.
CREATE OR REPLACE FUNCTION private.evolution_goals_sales(
    p_from date,
    p_to date,
    p_filiais text[] DEFAULT ARRAY[]::text[],
    p_fornecedores text[] DEFAULT ARRAY[]::text[],
    p_supervisores text[] DEFAULT ARRAY[]::text[],
    p_vendedores text[] DEFAULT ARRAY[]::text[],
    p_categorias text[] DEFAULT ARRAY[]::text[]
)
RETURNS TABLE(
    codusur text,
    codsupervisor text,
    month_key text,
    codfor text,
    categoria_produto text,
    mix_marca text,
    vlvenda numeric,
    totpesoliq numeric,
    codcli text,
    tipovenda text,
    filial text
)
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $function$
    WITH filters AS MATERIALIZED (
        SELECT
            private.evolution_goals_values(p_filiais) AS filiais,
            private.evolution_goals_values(p_fornecedores) AS fornecedores,
            private.evolution_goals_values(p_supervisores) AS supervisores,
            private.evolution_goals_values(p_vendedores) AS vendedores,
            private.evolution_goals_values(p_categorias) AS categorias
    ),
    supervisor_by_seller AS MATERIALIZED (
        SELECT * FROM private.evolution_goals_supervisor_by_seller()
    ),
    category_mix AS MATERIALIZED (
        SELECT categoria_produto, min(mix_marca) AS mix_marca
        FROM public.dim_produtos
        WHERE categoria_produto IS NOT NULL AND mix_marca IS NOT NULL
        GROUP BY categoria_produto
    )
    SELECT
        s.codusur::text,
        COALESCE(sbs.codsupervisor, s.codsupervisor)::text,
        to_char(make_date(s.ano, s.mes, 1), 'YYYY-MM'),
        CASE WHEN left(s.codfor, 5) = '1119_' THEN '1119'
             ELSE ltrim(s.codfor::text, '0') END,
        upper(s.categoria_produto),
        upper(cm.mix_marca),
        s.vlvenda::numeric,
        s.peso::numeric,
        s.codcli::text,
        s.tipovenda::text,
        s.filial::text
    FROM public.data_summary_current s
    LEFT JOIN supervisor_by_seller sbs
      ON sbs.codusur = CASE s.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE s.codusur END
    LEFT JOIN category_mix cm ON cm.categoria_produto = s.categoria_produto
    LEFT JOIN public.dim_vendedores dv ON dv.codigo = s.codusur
    LEFT JOIN public.dim_supervisores ds ON ds.codigo = COALESCE(sbs.codsupervisor, s.codsupervisor)
    CROSS JOIN filters f
    WHERE make_date(s.ano, s.mes, 1) >= date_trunc('month', p_from)::date
      AND make_date(s.ano, s.mes, 1) < date_trunc('month', p_to)::date
      AND (cardinality(f.filiais) = 0 OR upper(s.filial) = ANY(f.filiais))
      AND (cardinality(f.vendedores) = 0
           OR upper(s.codusur) = ANY(f.vendedores)
           OR upper(trim(dv.nome)) = ANY(f.vendedores))
      AND (cardinality(f.supervisores) = 0
           OR upper(COALESCE(sbs.codsupervisor, s.codsupervisor)) = ANY(f.supervisores)
           OR upper(trim(ds.nome)) = ANY(f.supervisores))
      AND (cardinality(f.categorias) = 0
           OR upper(s.categoria_produto) = ANY(f.categorias)
           OR upper(cm.mix_marca) = ANY(f.categorias))
      AND (
          cardinality(f.fornecedores) = 0
          OR CASE WHEN left(s.codfor, 5) = '1119_' THEN '1119'
                  ELSE ltrim(s.codfor::text, '0') END = ANY(f.fornecedores)
          OR (
              CASE WHEN left(s.codfor, 5) = '1119_' THEN '1119'
                   ELSE ltrim(s.codfor::text, '0') END = '1119'
              AND EXISTS (
                  SELECT 1 FROM unnest(f.fornecedores) selected
                  WHERE selected = '1119'
                     OR (selected = '1119_QUAKER_KEROCOCO'
                         AND (upper(cm.mix_marca) IN ('QUAKER','KEROCOCO')
                              OR upper(s.categoria_produto) LIKE '%QUAKER%'
                              OR upper(s.categoria_produto) LIKE '%KEROCOCO%'))
                     OR (selected = '1119_TODDYNHO'
                         AND (upper(cm.mix_marca) = 'TODDYNHO'
                              OR upper(s.categoria_produto) LIKE '%TODDYNHO%'
                              OR upper(s.categoria_produto) LIKE '%TODYNHO%'))
                     OR (selected = '1119_TODDY'
                         AND (upper(cm.mix_marca) = 'TODDY'
                              OR upper(s.categoria_produto) = 'TODDY'
                              OR upper(s.categoria_produto) LIKE '%TODDY %'))
                     OR (selected = '1119_QUAKER'
                         AND (upper(cm.mix_marca) = 'QUAKER'
                              OR upper(s.categoria_produto) LIKE '%QUAKER%'))
                     OR (selected = '1119_KEROCOCO'
                         AND (upper(cm.mix_marca) = 'KEROCOCO'
                              OR upper(s.categoria_produto) LIKE '%KEROCOCO%'))
              )
          )
      );
$function$;

ALTER FUNCTION public.get_metas_anuais_chart_multi(
    integer, integer, text[], text[], text[], text[], text[]
) SET work_mem = '90MB';

ALTER FUNCTION public.get_metas_base_comparativo_multi(
    integer, integer, text[], text[], text[], text[], text[]
) SET work_mem = '90MB';
