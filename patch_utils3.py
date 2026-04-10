import re

with open('src/js/utils.js', 'r') as f:
    content = f.read()

content = content.replace('${escapeHtml(extraClasses).trim()} xmlns="http://', '${escapeHtml(extraClasses).trim()}" xmlns="http://')

with open('src/js/utils.js', 'w') as f:
    f.write(content)
