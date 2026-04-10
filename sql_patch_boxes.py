import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)
boxes_code = sql[boxes_idx:end_idx]

# OK, the `pre_positivacao_val` is ONLY inside the dynamic SQL variable definition `v_active_client_cond`.
# The actual CTEs have `%s` which gets replaced with it. This is perfectly correct.
# Are there any syntax errors? Let's check with node.
