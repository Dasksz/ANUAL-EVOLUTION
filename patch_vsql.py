import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

# Define the pattern to replace (from line 15 to 251 essentially)
# We can find the exact indices
lines = content.split('\n')
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if line.startswith("CREATE OR REPLACE FUNCTION get_frequency_table_data("):
        start_idx = i
    if line.startswith("END;") and start_idx != -1 and end_idx == -1:
        # verify it's closing the function
        if lines[i+1] == '$$;':
            end_idx = i + 1

if start_idx != -1 and end_idx != -1:
    print(f"Found get_frequency_table_data from line {start_idx} to {end_idx}")
