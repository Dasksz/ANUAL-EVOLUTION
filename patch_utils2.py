import re

with open('src/js/utils.js', 'r') as f:
    content = f.read()

content = content.replace('".trim()', '')
content = content.replace('${escapeHtml(extraClasses)}', '${escapeHtml(extraClasses).trim()}')

with open('src/js/utils.js', 'w') as f:
    f.write(content)
