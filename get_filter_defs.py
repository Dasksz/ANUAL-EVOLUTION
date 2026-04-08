import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

# Let's find getCurrentFilters definition
match = re.search(r'function getCurrentFilters\(\).*?\{.*?(return \{.*?\});', content, re.DOTALL)
if match:
    print(match.group(0))
