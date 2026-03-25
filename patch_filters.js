const fs = require('fs');

let code = fs.readFileSync('src/js/app.js', 'utf8');

// The issue happens because `data` returned from mocked endpoint `{"data":{},"error":null}` in playwright is just `{}`
// So `data.sellout_salty` is `undefined`.
// But wait, what if the REAL endpoint returns `data` missing some keys or if there's no data?
// In the app, if there's no data, it usually returns `{}` or `null`. So we should handle `undefined`.
// But actually, this only happens in playwright mock!
// Let's just fix it anyway in `app.js` to be bulletproof.

code = code.replace(/data\.sellout_salty/g, "(data.sellout_salty || 0)");
code = code.replace(/data\.sellout_foods/g, "(data.sellout_foods || 0)");
code = code.replace(/data\.base_clientes/g, "(data.base_clientes || 0)");
code = code.replace(/data\.aceleradores_qtd_marcas/g, "(data.aceleradores_qtd_marcas || 0)");
code = code.replace(/data\.positivacao_salty/g, "(data.positivacao_salty || 0)");
code = code.replace(/data\.positivacao_foods/g, "(data.positivacao_foods || 0)");
code = code.replace(/data\.aceleradores_realizado/g, "(data.aceleradores_realizado || 0)");

fs.writeFileSync('src/js/app.js', code);
