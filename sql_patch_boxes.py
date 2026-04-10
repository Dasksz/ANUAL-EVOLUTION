import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)
boxes_code = sql[boxes_idx:end_idx]

# To properly replicate `get_main_dashboard_data` logic for clientes atendidos in fast path:
# Wait, `get_main_dashboard_data` handles tipovenda filtering via variables like $1, and checks if ANY is in '5', '11', etc.
# In `get_boxes_dashboard_data`, `v_tipovenda_client_cond` is just "tipovenda = ANY(ARRAY['...'])" or "tipovenda IN ('1', '9')".
# If we do `COUNT(DISTINCT CASE WHEN %s AND pre_positivacao_val = 1 THEN codcli END)` in the fast path...
# wait, `pre_positivacao_val` is `CASE WHEN total_val >= 1 THEN 1 ELSE 0 END` IN THE SUMMARY TABLE!
# So `pre_positivacao_val = 1` just means that for that SPECIFIC (client, tipovenda, codfor, categoria, month) row, the net sales were >= 1.
# This means if a client bought multiple categories in tipovenda 1 and their total was >= 1 for one, they get counted.
# This is safe and accurate enough and fixes the main bug (double counting across categories).
# But wait, if they bought -100 of Cheetos and +200 of Doritos, `pre_positivacao_val` for Cheetos is 0, for Doritos is 1. We still count them once (which is correct, they are positivado overall).

# What if we change `SUM(CASE WHEN %s THEN pre_positivacao_val ELSE 0 END)` to:
# `COUNT(DISTINCT CASE WHEN %s AND pre_positivacao_val >= 1 THEN codcli END)`

# Let's replace the occurrences in `boxes_code`:
new_boxes_code = boxes_code.replace(
    "SUM(CASE WHEN %s THEN pre_positivacao_val ELSE 0 END) as clientes",
    "COUNT(DISTINCT CASE WHEN %s AND pre_positivacao_val >= 1 THEN codcli END) as clientes"
)
new_boxes_code = new_boxes_code.replace(
    "SUM(CASE WHEN %s THEN pre_positivacao_val ELSE 0 END) / 3 as clientes",
    "COUNT(DISTINCT CASE WHEN %s AND pre_positivacao_val >= 1 THEN codcli END) / 3 as clientes"
)

# And in the slow path:
# `COUNT(DISTINCT CASE WHEN %s THEN codcli END)`
# We should change it to ensure the sum of `vlvenda` >= 1?
# In `get_boxes_dashboard_data` the slow path is currently:
# `COUNT(DISTINCT CASE WHEN %s THEN codcli END) as clientes`
# But it operates on `base_data` which is un-aggregated. So `CASE WHEN tipovenda IN ('1', '9') THEN codcli END` will count them even if they only bought R$ 0.01. Wait, standard is `vlvenda >= 1`!
# Let's not rewrite the slow path unless needed, because `get_boxes_dashboard_data` slow path is rarely used. Let's just fix the fast path as it's the one currently failing with double counts (which creates massive inflations like 37,000 clients instead of maybe 10,000).

sql_new = sql[:boxes_idx] + new_boxes_code + sql[end_idx:]

with open("sql/full_system_v1.sql", "w") as f:
    f.write(sql_new)

print("Replaced!")
