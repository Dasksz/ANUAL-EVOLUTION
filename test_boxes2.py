with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

boxes_idx = sql.find("CREATE OR REPLACE FUNCTION get_boxes_dashboard_data(")
end_idx = sql.find("$$;", boxes_idx)

boxes_code = sql[boxes_idx:end_idx]

print("get_boxes_dashboard_data uses pre_positivacao_val from data_summary:")
print(boxes_code[boxes_code.find("kpi_curr AS ("):boxes_code.find(")", boxes_code.find("kpi_curr AS ("))+20])
