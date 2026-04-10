import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)
boxes_code = sql[boxes_idx:end_idx]

# Let's fix the `COUNT(DISTINCT CASE WHEN %s AND pre_positivacao_val >= 1 THEN codcli END)`
# If they don't filter by tipovenda = 5 or 11, then they are positivado if their tipovenda is NOT 5 or 11 and their vlvenda > 0 (which means pre_positivacao_val = 1 AND tipovenda NOT IN ('5','11')).

# Instead of rewriting `get_boxes_dashboard_data`, I can define `v_active_client_cond`.
# In `get_boxes_dashboard_data`:
print(boxes_code[boxes_code.find("v_tipovenda_client_cond :="):boxes_code.find("IF p_categoria")])
