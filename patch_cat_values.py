import re

with open("src/js/app.js", "r") as f:
    content = f.read()

# These variables need escaping even if they are Math.round, better safe than sorry
content = content.replace('${catEstoque} cx', '${escapeHtml(catEstoque)} cx')
content = content.replace('${catPosAvg12m}', '${escapeHtml(catPosAvg12m)}')
content = content.replace('${catPosPrevYear}', '${escapeHtml(catPosPrevYear)}')
content = content.replace('${catPosPrevM1}', '${escapeHtml(catPosPrevM1)}')
content = content.replace('${catPosAtual}', '${escapeHtml(catPosAtual)}')
content = content.replace('${varColor}', '${escapeHtml(varColor)}')
content = content.replace('${varPercent}%', '${escapeHtml(varPercent)}%')

# Same for children (products)
content = content.replace('${pEstoque} cx', '${escapeHtml(pEstoque)} cx')
content = content.replace('${posAvg12m}', '${escapeHtml(posAvg12m)}')
content = content.replace('${posPrevYear}', '${escapeHtml(posPrevYear)}')
content = content.replace('${posPrevM1}', '${escapeHtml(posPrevM1)}')
content = content.replace('${posAtual}', '${escapeHtml(posAtual)}')
content = content.replace('${pVarColor}', '${escapeHtml(pVarColor)}')
content = content.replace('${pVarPercent}%', '${escapeHtml(pVarPercent)}%')

with open("src/js/app.js", "w") as f:
    f.write(content)
