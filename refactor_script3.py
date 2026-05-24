import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

def replacer(match):
    args = list(match.groups())
    btn, dropdown, container, items, selectedArray, searchInput, isObject = args
    isObject = isObject if isObject else 'false'
    searchInput = searchInput if searchInput else 'null'
    return f'window.setupMultiSelect({btn}, {dropdown}, {container}, {items}, {selectedArray}, () => {{}}, {isObject}, {searchInput})'

pattern_city = r'(?<!function\s)setupCityMultiSelect\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,)]+)(?:,\s*([^,)]+))?(?:,\s*([^,)]+))?\s*\)'
content = re.sub(pattern_city, replacer, content)

pattern_branch = r'(?<!function\s)setupBranchMultiSelect\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,)]+)(?:,\s*([^,)]+))?(?:,\s*([^,)]+))?\s*\)'
content = re.sub(pattern_branch, replacer, content)

# Remove function definitions properly
content = re.sub(r'function\s+setupCityMultiSelect\s*\([^)]*\)\s*\{\s*return\s+window\.setupMultiSelect[^;]+;\s*\}', '', content)
content = re.sub(r'function\s+setupBranchMultiSelect\s*\([^)]*\)\s*\{\s*return\s+window\.setupMultiSelect[^;]+;\s*\}', '', content)

content = content.replace("logic in setupCityMultiSelect handles", "logic in window.setupMultiSelect handles")
content = content.replace("typeof setupCityMultiSelect === 'function'", "typeof window.setupMultiSelect === 'function'")
content = content.replace("Actually we need to call setupCityMultiSelect on wrappers if possible...", "Actually we need to call window.setupMultiSelect on wrappers if possible...")


with open('src/js/app.js', 'w') as f:
    f.write(content)
