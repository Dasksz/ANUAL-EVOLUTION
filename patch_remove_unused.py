import re

with open('src/js/app.js', 'r') as f:
    content = f.read()

# remove createDetalhadoRow as it's no longer used
pattern = re.compile(r"""/\*\*.*?function createDetalhadoRow.*?return tr;\n\}\n""", re.DOTALL)
content = pattern.sub("", content)

with open('src/js/app.js', 'w') as f:
    f.write(content)
