with open("sql/full_system_v1.sql", "r") as f:
    content = f.read()

# I need to update get_estrelas_kpis_data CTE sales_data and aceleradores_calc.
# The original code:

#         sales_data AS (
#             SELECT
#                 SUM(s.peso) as total_tonnage,
#                 -- Salty Tonnage
#                 SUM(CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.peso ELSE 0 END) as salty_tonnage,
#                 -- Foods Tonnage
#                 SUM(CASE WHEN s.codfor IN (''1119'') THEN s.peso ELSE 0 END) as foods_tonnage,
#
#                 -- Salty Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.codcli END) as positivacao_salty,
#                 -- Foods Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') THEN s.codcli END) as positivacao_foods
#             FROM target_sales s
#         ),
#         aceleradores_config AS (
#             SELECT array_agg(nome_categoria) as nomes FROM public.config_aceleradores
#         ),
#         aceleradores_calc AS (
#             SELECT
#                 COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
#                 COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
#             FROM target_sales s
#         )

# But wait, `target_sales` is reading from `public.data_summary_frequency` which already has `vlvenda >= 1` in many places? Wait! `data_summary_frequency` doesn't have `vlvenda >= 1` by default! It's pre-aggregated by order (`pedido`), but the columns in it include `peso` and `categorias`. Wait, does it have a `vlvenda` column or a `total_val` column we can filter by? Let's check `data_summary_frequency` definition.
