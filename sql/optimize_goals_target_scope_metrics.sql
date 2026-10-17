-- Compute the all-seller and filtered seller metrics in one pass over the
-- same indexed summary source used by the main dashboard.
CREATE OR REPLACE FUNCTION private.evolution_goals_scope_metrics(
    p_ano integer,
    p_mes integer,
    p_filiais text[] DEFAULT ARRAY[]::text[],
    p_fornecedores text[] DEFAULT ARRAY[]::text[],
    p_supervisores text[] DEFAULT ARRAY[]::text[],
    p_vendedores text[] DEFAULT ARRAY[]::text[],
    p_categorias text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
SET work_mem = '90MB'
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
    SELECT s.*
    FROM private.evolution_goals_supervisor_by_seller() s
    CROSS JOIN filters f
    WHERE cardinality(f.supervisores) > 0
),
category_mix AS MATERIALIZED (
    SELECT categoria_produto, min(mix_marca) AS mix_marca
    FROM public.dim_produtos
    WHERE categoria_produto IS NOT NULL AND mix_marca IS NOT NULL
    GROUP BY categoria_produto
),
raw_all AS MATERIALIZED (
    SELECT
        d.codusur::text AS codusur,
        COALESCE(sbs.codsupervisor, d.codsupervisor)::text AS codsupervisor,
        d.ano,
        d.mes,
        CASE WHEN left(d.codfor, 5) = '1119_' THEN '1119'
             ELSE ltrim(d.codfor::text, '0') END AS codfor,
        upper(d.categoria_produto) AS categoria_produto,
        upper(cm.mix_marca) AS mix_marca,
        d.vlvenda::numeric AS vlvenda,
        d.peso::numeric AS peso,
        d.codcli::text AS codcli,
        d.filial::text AS filial,
        upper(trim(dv.nome)) AS vendedor_nome,
        upper(trim(ds.nome)) AS supervisor_nome
    FROM public.data_summary_current d
    LEFT JOIN supervisor_by_seller sbs
      ON sbs.codusur = CASE d.codusur WHEN '53' THEN 'BALCAO_SP' WHEN '1001' THEN 'AMERICANAS' ELSE d.codusur END
    LEFT JOIN category_mix cm ON cm.categoria_produto = d.categoria_produto
    JOIN public.dim_vendedores dv ON dv.codigo = d.codusur
      AND upper(trim(dv.nome)) NOT LIKE 'INATIVOS%'
    LEFT JOIN public.dim_supervisores ds ON ds.codigo = COALESCE(sbs.codsupervisor, d.codsupervisor)
    WHERE d.ano BETWEEN p_ano - 1 AND p_ano
      AND (d.ano < p_ano OR d.mes < p_mes)
      AND d.ano * 12 + d.mes >= (p_ano * 12 + p_mes - 3)
      AND d.tipovenda IN ('1', '9')
),
scoped_rows AS MATERIALIZED (
    SELECT 'all'::text AS scope, r.* FROM raw_all r
    UNION ALL
    SELECT 'selected'::text AS scope, r.*
    FROM raw_all r CROSS JOIN filters f
    WHERE (cardinality(f.filiais) = 0 OR upper(r.filial) = ANY(f.filiais))
      AND (cardinality(f.vendedores) = 0 OR upper(r.codusur) = ANY(f.vendedores) OR r.vendedor_nome = ANY(f.vendedores))
      AND (cardinality(f.supervisores) = 0 OR upper(r.codsupervisor) = ANY(f.supervisores) OR r.supervisor_nome = ANY(f.supervisores))
      AND (cardinality(f.categorias) = 0 OR r.categoria_produto = ANY(f.categorias) OR r.mix_marca = ANY(f.categorias))
      AND (
          cardinality(f.fornecedores) = 0
          OR r.codfor = ANY(f.fornecedores)
          OR (r.codfor = '1119' AND EXISTS (
              SELECT 1 FROM unnest(f.fornecedores) selected
              WHERE selected = '1119'
                 OR (selected = '1119_QUAKER_KEROCOCO' AND (r.mix_marca IN ('QUAKER','KEROCOCO') OR r.categoria_produto LIKE '%QUAKER%' OR r.categoria_produto LIKE '%KEROCOCO%'))
                 OR (selected = '1119_TODDYNHO' AND (r.mix_marca = 'TODDYNHO' OR r.categoria_produto LIKE '%TODDYNHO%' OR r.categoria_produto LIKE '%TODYNHO%'))
                 OR (selected = '1119_TODDY' AND (r.mix_marca = 'TODDY' OR r.categoria_produto = 'TODDY' OR r.categoria_produto LIKE '%TODDY %'))
                 OR (selected = '1119_QUAKER' AND (r.mix_marca = 'QUAKER' OR r.categoria_produto LIKE '%QUAKER%'))
                 OR (selected = '1119_KEROCOCO' AND (r.mix_marca = 'KEROCOCO' OR r.categoria_produto LIKE '%KEROCOCO%'))
          ))
      )
),
seller_client_month AS (
    SELECT scope, codusur, ano, mes, codcli,
        sum(vlvenda) AS fat_geral,
        sum(peso) AS vol_geral,
        sum(vlvenda) FILTER (WHERE codfor IN ('707','708','752')) AS fat_elma,
        sum(peso) FILTER (WHERE codfor IN ('707','708','752')) AS vol_elma,
        bool_or(vlvenda > 0 AND codfor IN ('707','708','752')) AS pos_elma,
        sum(vlvenda) FILTER (WHERE codfor = '707') AS fat_707,
        bool_or(vlvenda > 0 AND codfor = '707') AS pos_707,
        sum(vlvenda) FILTER (WHERE codfor = '708') AS fat_708,
        bool_or(vlvenda > 0 AND codfor = '708') AS pos_708,
        sum(vlvenda) FILTER (WHERE codfor = '752') AS fat_752,
        bool_or(vlvenda > 0 AND codfor = '752') AS pos_752,
        sum(vlvenda) FILTER (WHERE codfor = '1119') AS fat_foods,
        sum(peso) FILTER (WHERE codfor = '1119') AS vol_foods,
        bool_or(vlvenda > 0 AND codfor = '1119') AS pos_foods,
        sum(vlvenda) FILTER (WHERE codfor = '1119' AND (categoria_produto LIKE '%TODDYNHO%' OR categoria_produto LIKE '%TODYNHO%')) AS fat_toddynho,
        bool_or(vlvenda > 0 AND codfor = '1119' AND (categoria_produto LIKE '%TODDYNHO%' OR categoria_produto LIKE '%TODYNHO%')) AS pos_toddynho,
        sum(vlvenda) FILTER (WHERE codfor = '1119' AND (categoria_produto LIKE '%TODDY %' OR categoria_produto = 'TODDY')) AS fat_toddy,
        bool_or(vlvenda > 0 AND codfor = '1119' AND (categoria_produto LIKE '%TODDY %' OR categoria_produto = 'TODDY')) AS pos_toddy,
        sum(vlvenda) FILTER (WHERE codfor = '1119' AND (categoria_produto LIKE '%QUAKER%' OR categoria_produto LIKE '%KEROCOCO%')) AS fat_quaker_kerococo,
        bool_or(vlvenda > 0 AND codfor = '1119' AND (categoria_produto LIKE '%QUAKER%' OR categoria_produto LIKE '%KEROCOCO%')) AS pos_quaker_kerococo,
        bool_or(vlvenda > 0 AND mix_marca = 'CHEETOS') AS has_cheetos,
        bool_or(vlvenda > 0 AND mix_marca = 'DORITOS') AS has_doritos,
        bool_or(vlvenda > 0 AND mix_marca = 'FANDANGOS') AS has_fandangos,
        bool_or(vlvenda > 0 AND mix_marca = 'RUFFLES') AS has_ruffles,
        bool_or(vlvenda > 0 AND mix_marca = 'TORCIDA') AS has_torcida,
        bool_or(vlvenda > 0 AND mix_marca = 'TODDYNHO') AS has_toddynho,
        bool_or(vlvenda > 0 AND mix_marca = 'TODDY') AS has_toddy,
        bool_or(vlvenda > 0 AND mix_marca = 'QUAKER') AS has_quaker,
        bool_or(vlvenda > 0 AND mix_marca = 'KEROCOCO') AS has_kerococo
    FROM scoped_rows
    GROUP BY scope, codusur, ano, mes, codcli
),
seller_month AS (
    SELECT scope, codusur, ano, mes,
        sum(fat_geral) AS fat_geral,
        sum(vol_geral) AS vol_geral,
        count(*) FILTER (WHERE codcli IS NOT NULL) AS pos_geral,
        sum(fat_elma) AS fat_elma, sum(vol_elma) AS vol_elma, count(*) FILTER (WHERE pos_elma) AS pos_elma,
        sum(fat_707) AS fat_707, count(*) FILTER (WHERE pos_707) AS pos_707,
        sum(fat_708) AS fat_708, count(*) FILTER (WHERE pos_708) AS pos_708,
        sum(fat_752) AS fat_752, count(*) FILTER (WHERE pos_752) AS pos_752,
        sum(fat_foods) AS fat_foods, sum(vol_foods) AS vol_foods, count(*) FILTER (WHERE pos_foods) AS pos_foods,
        sum(fat_toddynho) AS fat_toddynho, count(*) FILTER (WHERE pos_toddynho) AS pos_toddynho,
        sum(fat_toddy) AS fat_toddy, count(*) FILTER (WHERE pos_toddy) AS pos_toddy,
        sum(fat_quaker_kerococo) AS fat_quaker_kerococo, count(*) FILTER (WHERE pos_quaker_kerococo) AS pos_quaker_kerococo,
        count(*) FILTER (WHERE has_cheetos AND has_doritos AND has_fandangos AND has_ruffles AND has_torcida) AS mix_salty,
        count(*) FILTER (WHERE has_toddynho AND has_toddy AND has_quaker AND has_kerococo) AS mix_foods
    FROM seller_client_month
    GROUP BY scope, codusur, ano, mes
),
seller_totals AS (
    SELECT scope, codusur,
        coalesce(sum(fat_geral),0) AS total_fat_geral, coalesce(sum(vol_geral),0) AS total_vol_geral, coalesce(sum(pos_geral),0) AS sum_pos_geral,
        coalesce(sum(fat_elma),0) AS total_fat_elma, coalesce(sum(vol_elma),0) AS total_vol_elma, coalesce(sum(pos_elma),0) AS sum_pos_elma,
        coalesce(sum(fat_707),0) AS total_fat_707, coalesce(sum(pos_707),0) AS sum_pos_707,
        coalesce(sum(fat_708),0) AS total_fat_708, coalesce(sum(pos_708),0) AS sum_pos_708,
        coalesce(sum(fat_752),0) AS total_fat_752, coalesce(sum(pos_752),0) AS sum_pos_752,
        coalesce(sum(fat_foods),0) AS total_fat_foods, coalesce(sum(vol_foods),0) AS total_vol_foods, coalesce(sum(pos_foods),0) AS sum_pos_foods,
        coalesce(sum(fat_toddynho),0) AS total_fat_toddynho, coalesce(sum(pos_toddynho),0) AS sum_pos_toddynho,
        coalesce(sum(fat_toddy),0) AS total_fat_toddy, coalesce(sum(pos_toddy),0) AS sum_pos_toddy,
        coalesce(sum(fat_quaker_kerococo),0) AS total_fat_quaker_kerococo, coalesce(sum(pos_quaker_kerococo),0) AS sum_pos_quaker_kerococo,
        coalesce(sum(mix_salty),0) AS sum_mix_salty, coalesce(sum(mix_foods),0) AS sum_mix_foods
    FROM seller_month
    GROUP BY scope, codusur
)
SELECT jsonb_build_object(
    'all_sellers', coalesce(jsonb_agg(to_jsonb(seller_totals) - 'scope') FILTER (WHERE scope='all'), '[]'::jsonb),
    'selected_sellers', coalesce(jsonb_agg(to_jsonb(seller_totals) - 'scope') FILTER (WHERE scope='selected'), '[]'::jsonb)
)
FROM seller_totals;
$function$;

REVOKE ALL ON FUNCTION private.evolution_goals_scope_metrics(
    integer, integer, text[], text[], text[], text[], text[]
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.evolution_goals_targets(
    p_ano integer,
    p_mes integer,
    p_filiais text[] DEFAULT ARRAY[]::text[],
    p_fornecedores text[] DEFAULT ARRAY[]::text[],
    p_supervisores text[] DEFAULT ARRAY[]::text[],
    p_vendedores text[] DEFAULT ARRAY[]::text[],
    p_categorias text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
SET work_mem = '90MB'
AS $function$
DECLARE
    metrics jsonb;
    result jsonb;
BEGIN
    PERFORM private.evolution_assert_approved();
    metrics := private.evolution_goals_scope_metrics(p_ano, p_mes, p_filiais, p_fornecedores, p_supervisores, p_vendedores, p_categorias);
    WITH all_sellers AS (
        SELECT value AS s FROM jsonb_array_elements(metrics->'all_sellers')
    ), selected AS (
        SELECT value AS s FROM jsonb_array_elements(metrics->'selected_sellers')
    ), metas AS (
        SELECT DISTINCT ON (dv.codigo, m.categoria, m.metrica)
            m.*, dv.codigo AS code, dv.nome AS seller_name,
            private.evolution_goals_target_field(m.categoria, m.metrica) AS field
        FROM public.farol_metas_current m
        JOIN public.dim_vendedores dv ON
            ((m.codusur IS NOT NULL AND dv.codigo=m.codusur)
             OR (m.codusur IS NULL AND upper(trim(dv.nome))=upper(trim(m.vendedor_nome))))
        WHERE m.ano=p_ano AND m.mes=p_mes AND upper(dv.nome) NOT LIKE 'INATIVOS%'
        ORDER BY dv.codigo,m.categoria,m.metrica,m.updated_at DESC,m.id
    ), weights AS (
        SELECT m.*, a.s AS all_s, s.s AS scoped_s,
            CASE
                WHEN coalesce((a.s->>m.field)::numeric,0)>0
                    THEN least(1,greatest(0,coalesce((s.s->>m.field)::numeric,0)/(a.s->>m.field)::numeric))
                WHEN coalesce(cardinality(private.evolution_goals_values(p_filiais)),0)=0
                 AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
                 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0
                 AND coalesce(cardinality(private.evolution_goals_values(p_supervisores)),0)=0
                 AND private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores)) THEN 1
                WHEN a.s IS NULL AND 'SEM SUPERVISOR'=ANY(private.evolution_goals_values(p_supervisores))
                 AND coalesce(cardinality(p_filiais),0)=0 AND coalesce(cardinality(p_fornecedores),0)=0 AND coalesce(cardinality(p_categorias),0)=0 THEN 1
                WHEN s.s IS NOT NULL AND coalesce(cardinality(private.evolution_goals_values(p_fornecedores)),0)=0
                 AND coalesce(cardinality(private.evolution_goals_values(p_categorias)),0)=0 THEN 1
                ELSE 0
            END AS factor
        FROM metas m
        LEFT JOIN all_sellers a ON a.s->>'codusur'=m.code
        LEFT JOIN selected s ON s.s->>'codusur'=m.code
        WHERE private.evolution_goals_match(m.code,m.seller_name,private.evolution_goals_values(p_vendedores))
    ), allowed AS (
        SELECT w.* FROM weights w
        WHERE factor>0 AND (
            coalesce(cardinality(p_fornecedores),0)=0
            OR w.categoria IN ('pepsico_all','pedev','mix_salty','mix_foods','total_elma','total_foods','tonelada_elma','tonelada_foods')
            OR w.categoria=ANY(p_fornecedores)
            OR ('1119'=ANY(p_fornecedores) AND w.categoria LIKE '1119_%')
            OR (w.categoria='1119_QUAKER_KEROCOCO' AND p_fornecedores && ARRAY['1119_QUAKER','1119_KEROCOCO'])
        )
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id',id,'ano',ano,'mes',mes,'codusur',code,'vendedor_nome',seller_name,
        'categoria',categoria,'metrica',metrica,
        'valor_ajuste',CASE WHEN metrica IN ('POS','MIX') THEN round(valor_ajuste*factor) ELSE valor_ajuste*factor END,
        'source_value',valor_ajuste,'scope_factor',factor
    )), '[]'::jsonb) INTO result FROM allowed;
    RETURN result;
END;
$function$;
