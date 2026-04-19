import re

with open("src/js/app.js", "r") as f:
    content = f.read()

# currentDate needs to be escaped
new_content = content.replace('Gerado em: ${currentDate}', 'Gerado em: ${escapeHtml(currentDate)}')

with open("src/js/app.js", "w") as f:
    f.write(new_content)
