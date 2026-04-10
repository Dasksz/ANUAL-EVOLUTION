with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)
boxes_code = sql[boxes_idx:end_idx]

print(boxes_code[boxes_code.find("IF v_use_cache THEN"):boxes_code.find("SELECT", boxes_code.find("prod_agg AS ("))])
