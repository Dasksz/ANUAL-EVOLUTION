import re

for filename in ['sql/full_system_v1.sql', 'sql/migration_boxes.sql']:
    with open(filename, 'r') as f:
        sql = f.read()

    # In the slow path, chart_agg_base is missing! We deleted it when we did regex replacement on salty_monthly.
    # Oh wait, we used string replace!
    # Looking at the output above, around line 3508:
    #             ),
    #             chart_agg AS (
    #
    # Wait, where is chart_agg_base AS ( ???
    # It's totally missing from the slow path!

    missing_text = """            chart_agg_base AS (
                SELECT
                    EXTRACT(MONTH FROM dtped)::int - 1 as m_idx,
                    EXTRACT(YEAR FROM dtped)::int as yr,
                    SUM(CASE WHEN tipovenda IN (''5'', ''11'') THEN vlbonific::numeric ELSE vlvenda::numeric END) as fat,
                    SUM(totpesoliq) as peso,
                    SUM(COALESCE(qtvenda, 0) / COALESCE(NULLIF(qtde_embalagem_master, 0), 1)) as caixas,
                    COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes
                FROM base_data s
                GROUP BY 1, 2
            ),
"""
    sql = sql.replace(
        "            ),\n            chart_agg AS (\n                SELECT b.*\n                FROM chart_agg_base b\n                            ),",
        "            ),\n" + missing_text + "            chart_agg AS (\n                SELECT b.*\n                FROM chart_agg_base b\n            ),"
    )

    with open(filename, 'w') as f:
        f.write(sql)
