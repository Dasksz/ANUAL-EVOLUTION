import re
with open("sql/full_system_v1.sql", "r") as f:
    sql = f.read()

pattern = r"CREATE OR REPLACE FUNCTION get_innovations_data\([\s\S]*?\$BODY\$;"
match = re.search(pattern, sql)
if match:
    print("Function replaced correctly.")
    print(match.group(0)[:100])
else:
    print("Function not found!")
