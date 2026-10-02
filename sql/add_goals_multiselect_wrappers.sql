-- Multi-selection support for the Goals panel.
-- Empty arrays mean "Todos/Todas". Values are aggregated by summing the
-- existing scalar Goals calculations, preserving current business rules.

CREATE OR REPLACE FUNCTION private.evolution_sum_jsonb_objects(a jsonb, b jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    result jsonb := COALESCE(a, '{}'::jsonb);
    k text;
    v jsonb;
    av jsonb;
BEGIN
    IF b IS NULL THEN RETURN result; END IF;
    FOR k, v IN SELECT key, value FROM jsonb_each(b)
    LOOP
        av := result -> k;
        IF jsonb_typeof(v) = 'number' AND jsonb_typeof(av) = 'number' THEN
            result := jsonb_set(result, ARRAY[k], to_jsonb((av #>> '{}')::numeric + (v #>> '{}')::numeric), true);
        ELSIF jsonb_typeof(v) = 'object' AND jsonb_typeof(av) = 'object' THEN
            result := jsonb_set(result, ARRAY[k], private.evolution_sum_jsonb_objects(av, v), true);
        ELSIF av IS NULL THEN
            result := jsonb_set(result, ARRAY[k], v, true);
        END IF;
    END LOOP;
    RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_metas_base_comparativo_multi(
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
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
    v_filiais text[] := CASE WHEN COALESCE(cardinality(p_filiais),0)=0 THEN ARRAY['Todas'] ELSE p_filiais END;
    v_fornecedores text[] := CASE WHEN COALESCE(cardinality(p_fornecedores),0)=0 THEN ARRAY['Todos'] ELSE p_fornecedores END;
    v_categorias text[] := CASE WHEN COALESCE(cardinality(p_categorias),0)=0 THEN ARRAY['Todos'] ELSE p_categorias END;
    v_principals text[];
    v_use_vendedores boolean := COALESCE(cardinality(p_vendedores),0)>0;
    v_filial text; v_fornecedor text; v_categoria text; v_principal text;
    v_res jsonb; v_seller jsonb; v_code text;
    v_sellers_map jsonb := '{}'::jsonb;
    v_quarter jsonb := '[]'::jsonb;
BEGIN
    PERFORM private.evolution_assert_approved();
    v_principals := CASE
        WHEN v_use_vendedores THEN p_vendedores
        WHEN COALESCE(cardinality(p_supervisores),0)>0 THEN p_supervisores
        ELSE ARRAY[NULL::text]
    END;

    FOREACH v_filial IN ARRAY v_filiais LOOP
      FOREACH v_fornecedor IN ARRAY v_fornecedores LOOP
        FOREACH v_categoria IN ARRAY v_categorias LOOP
          FOREACH v_principal IN ARRAY v_principals LOOP
            v_res := public.get_metas_base_comparativo_filtered(
                p_ano, p_mes, v_filial, v_fornecedor,
                CASE WHEN v_use_vendedores THEN NULL ELSE v_principal END,
                CASE WHEN v_use_vendedores THEN v_principal ELSE NULL END,
                v_categoria
            );
            IF v_quarter = '[]'::jsonb THEN v_quarter := COALESCE(v_res->'quarterMonths','[]'::jsonb); END IF;
            FOR v_seller IN SELECT value FROM jsonb_array_elements(COALESCE(v_res->'sellers','[]'::jsonb))
            LOOP
                v_code := COALESCE(v_seller->>'codusur', v_seller->>'vendedor_nome');
                IF v_code IS NULL THEN CONTINUE; END IF;
                IF v_sellers_map ? v_code THEN
                    v_sellers_map := jsonb_set(v_sellers_map, ARRAY[v_code],
                        private.evolution_sum_jsonb_objects(v_sellers_map->v_code, v_seller), true);
                ELSE
                    v_sellers_map := jsonb_set(v_sellers_map, ARRAY[v_code], v_seller, true);
                END IF;
            END LOOP;
          END LOOP;
        END LOOP;
      END LOOP;
    END LOOP;

    RETURN jsonb_build_object(
        'quarterMonths', v_quarter,
        'sellers', COALESCE((SELECT jsonb_agg(value ORDER BY value->>'vendedor_nome') FROM jsonb_each(v_sellers_map)), '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_metas_anuais_chart_multi(
    p_ano integer,
    p_mes_atual integer DEFAULT 12,
    p_filiais text[] DEFAULT ARRAY[]::text[],
    p_fornecedores text[] DEFAULT ARRAY[]::text[],
    p_supervisores text[] DEFAULT ARRAY[]::text[],
    p_vendedores text[] DEFAULT ARRAY[]::text[],
    p_categorias text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
    v_filiais text[] := CASE WHEN COALESCE(cardinality(p_filiais),0)=0 THEN ARRAY['Todas'] ELSE p_filiais END;
    v_fornecedores text[] := CASE WHEN COALESCE(cardinality(p_fornecedores),0)=0 THEN ARRAY['Todos'] ELSE p_fornecedores END;
    v_categorias text[] := CASE WHEN COALESCE(cardinality(p_categorias),0)=0 THEN ARRAY['Todos'] ELSE p_categorias END;
    v_principals text[];
    v_use_vendedores boolean := COALESCE(cardinality(p_vendedores),0)>0;
    v_filial text; v_fornecedor text; v_categoria text; v_principal text;
    v_res jsonb; v_row jsonb; v_month text;
    v_rows jsonb := '{}'::jsonb;
    v_top jsonb := '{}'::jsonb;
    v_growth jsonb := NULL;
    v_closed integer := 0;
BEGIN
    PERFORM private.evolution_assert_approved();
    v_principals := CASE
        WHEN v_use_vendedores THEN p_vendedores
        WHEN COALESCE(cardinality(p_supervisores),0)>0 THEN p_supervisores
        ELSE ARRAY[NULL::text]
    END;

    FOREACH v_filial IN ARRAY v_filiais LOOP
      FOREACH v_fornecedor IN ARRAY v_fornecedores LOOP
        FOREACH v_categoria IN ARRAY v_categorias LOOP
          FOREACH v_principal IN ARRAY v_principals LOOP
            v_res := public.get_metas_anuais_chart(
                p_ano,
                CASE WHEN v_use_vendedores THEN NULL ELSE v_principal END,
                CASE WHEN v_use_vendedores THEN v_principal ELSE NULL END,
                p_mes_atual, v_categoria, v_filial, v_fornecedor
            );
            IF v_growth IS NULL THEN v_growth := v_res->'percentual_crescimento'; END IF;
            v_closed := GREATEST(v_closed, COALESCE((v_res->>'mes_fechado')::integer,0));
            v_top := private.evolution_sum_jsonb_objects(
                v_top, v_res - 'chart_data' - 'percentual_crescimento' - 'mes_fechado'
            );

            FOR v_row IN SELECT value FROM jsonb_array_elements(COALESCE(v_res->'chart_data','[]'::jsonb))
            LOOP
                v_month := v_row->>'mes';
                IF v_month IS NULL THEN CONTINUE; END IF;
                IF v_rows ? v_month THEN
                    v_rows := jsonb_set(v_rows, ARRAY[v_month],
                        private.evolution_sum_jsonb_objects(v_rows->v_month, v_row - 'mes')
                        || jsonb_build_object('mes',(v_month)::integer), true);
                ELSE
                    v_rows := jsonb_set(v_rows, ARRAY[v_month], v_row, true);
                END IF;
            END LOOP;
          END LOOP;
        END LOOP;
      END LOOP;
    END LOOP;

    RETURN v_top || jsonb_build_object(
        'percentual_crescimento', v_growth,
        'mes_fechado', v_closed,
        'chart_data', COALESCE((
            SELECT jsonb_agg(value ORDER BY (value->>'mes')::integer)
            FROM jsonb_each(v_rows)
        ), '[]'::jsonb)
    );
END;
$$;
