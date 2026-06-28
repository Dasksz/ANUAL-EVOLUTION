import re

with open("sql/full_system_v1.sql", "r", encoding="utf-8") as f:
    content = f.read()

# We need to filter out bonifications/losses?
# In other queries, what are the normal tipovenda filters?
