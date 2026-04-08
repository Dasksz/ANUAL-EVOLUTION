import re

with open('src/js/app.js', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "p_codcli: filters.p_codcli" in line:
        print(f"Found p_codcli at line {i+1}: {line.strip()}")
