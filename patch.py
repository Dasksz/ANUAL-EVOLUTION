import re

with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

with open("/tmp/new_innov_func.sql", "r") as f:
    new_func = f.read()

# Replace everything from "CREATE OR REPLACE FUNCTION get_innovations_data("
# up to the end of its body matching "$BODY$;"
pattern = r"CREATE OR REPLACE FUNCTION get_innovations_data\([\s\S]*?\$BODY\$;"
replaced = re.sub(pattern, new_func, sql)

with open("sql/full_system_v1.sql", "w") as f:
    f.write(replaced)

print("Replaced!")
