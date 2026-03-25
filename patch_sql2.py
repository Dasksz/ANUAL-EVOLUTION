with open("sql/full_system_v1.sql", "r") as f:
    content = f.read()

# We need to change:
#                 -- Salty Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.codcli END) as positivacao_salty,
#                 -- Foods Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') THEN s.codcli END) as positivacao_foods
# TO:
#                 -- Salty Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_salty,
#                 -- Foods Positivacao
#                 COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_foods

# And for aceleradores:
#                 COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
#                 COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
# TO:
#                 COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
#                 COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial

search_sales = """                -- Salty Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') THEN s.codcli END) as positivacao_salty,
                -- Foods Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') THEN s.codcli END) as positivacao_foods"""

replace_sales = """                -- Salty Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''707'', ''708'', ''752'') AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_salty,
                -- Foods Positivacao
                COUNT(DISTINCT CASE WHEN s.codfor IN (''1119'') AND s.vlvenda >= 1 THEN s.codcli END) as positivacao_foods"""

search_acel = """        aceleradores_calc AS (
            SELECT
                COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
                COUNT(DISTINCT CASE WHEN (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
            FROM target_sales s
        )"""

replace_acel = """        aceleradores_calc AS (
            SELECT
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias)) THEN s.codcli END) as aceleradores_realizado,
                COUNT(DISTINCT CASE WHEN s.vlvenda >= 1 AND (SELECT nomes FROM aceleradores_config) IS NOT NULL AND (SELECT nomes FROM aceleradores_config) && ARRAY(SELECT jsonb_array_elements_text(s.categorias)) AND NOT ((SELECT nomes FROM aceleradores_config) <@ ARRAY(SELECT jsonb_array_elements_text(s.categorias))) THEN s.codcli END) as aceleradores_parcial
            FROM target_sales s
        )"""

if search_sales in content and search_acel in content:
    content = content.replace(search_sales, replace_sales)
    content = content.replace(search_acel, replace_acel)
    with open("sql/full_system_v1.sql", "w") as f:
        f.write(content)
    print("SQL patched successfully")
else:
    print("Search strings not found")
