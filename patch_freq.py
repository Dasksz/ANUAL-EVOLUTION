import re

with open("src/js/app.js", "r") as f:
    content = f.read()

# Root data needs escape in footer
content = content.replace('${rootData.tons.toFixed(1)}', '${escapeHtml(rootData.tons.toFixed(1))}')
content = content.replace('${rootData.skuPdv.toFixed(2)}', '${escapeHtml(rootData.skuPdv.toFixed(2))}')
content = content.replace('${rootData.freq.toFixed(2)}', '${escapeHtml(rootData.freq.toFixed(2))}')
content = content.replace('${rootData.positivacao}', '${escapeHtml(rootData.positivacao)}')
content = content.replace('${rootData.percPosit.toFixed(1)}', '${escapeHtml(rootData.percPosit.toFixed(1))}')

with open("src/js/app.js", "w") as f:
    f.write(content)
