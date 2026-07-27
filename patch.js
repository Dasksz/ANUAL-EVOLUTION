const fs = require('fs');

let content = fs.readFileSync('src/js/presentation.js', 'utf8');

const oldCode = `        // "Rede" is now conceptually "Atacado"
        const topAtacado = redesData.sort((a,b) => b.fat_atual - a.fat_atual)[0] || redesData[0];

        container.innerHTML = \`
            <div class="presentation-card bg-gradient-to-br from-fuchsia-900/40 to-transparent border-fuchsia-500/30">
                <h3 class="text-lg font-bold text-white mb-4 border-b border-fuchsia-500/30 pb-2">Top Atacado: \${topAtacado.dimension}</h3>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Faturamento</div>
                        <div class="text-xl font-bold text-white">\${formatCurrency(topAtacado.fat_atual)}</div>
                        <div class="text-sm mt-1">\${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_trim)} vs Trim, \${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_ant)} vs Ano</div>
                    </div>
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Toneladas</div>
                        <div class="text-xl font-bold text-white">\${formatNumber(topAtacado.ton_atual)}</div>
                        <div class="text-sm mt-1">\${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_trim)} vs Trim, \${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_ant)} vs Ano</div>
                    </div>
                </div>
            </div>

            <div class="presentation-card">
                 <h3 class="text-sm font-bold text-slate-300 mb-4 border-b border-white/10 pb-2">Outros Atacados</h3>
                 <div class="space-y-3 max-h-48 overflow-y-auto custom-scrollbar pr-2">
                    \${redesData.filter(r => r.dimension !== topAtacado.dimension).map(r => \`
                        <div class="flex justify-between items-center bg-black/20 p-2 rounded">
                            <span class="text-sm font-medium text-slate-300 truncate w-32" title="\${r.dimension}">\${r.dimension}</span>
                            <span class="text-sm text-white">\${formatCurrency(r.fat_atual)}</span>
                            <span class="text-xs">\${renderVarBadge(r.fat_atual, r.fat_trim)} vs Trim, \${renderVarBadge(r.fat_atual, r.fat_ant)} vs Ano</span>
                        </div>
                    \`).join('')}
                 </div>
            </div>
        \`;`;

const newCode = `        // "Rede" is now conceptually "Atacado"
        const topAtacado = redesData.sort((a,b) => b.fat_atual - a.fat_atual)[0] || redesData[0];

        // Helper to remove "Rede: " prefix
        const formatDim = (dim) => dim ? dim.replace(/^Rede:\\s*/i, '') : dim;

        const outrosAtacados = redesData.filter(r => r.dimension !== topAtacado.dimension);
        const totalFatOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_atual || 0), 0);
        const totalFatTrimOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_trim || 0), 0);
        const totalFatAntOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_ant || 0), 0);

        container.innerHTML = \`
            <div class="presentation-card bg-gradient-to-br from-fuchsia-900/40 to-transparent border-fuchsia-500/30">
                <h3 class="text-lg font-bold text-white mb-4 border-b border-fuchsia-500/30 pb-2">Top Atacado: \${formatDim(topAtacado.dimension)}</h3>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Faturamento</div>
                        <div class="text-xl font-bold text-white">\${formatCurrency(topAtacado.fat_atual)}</div>
                        <div class="text-sm mt-1">\${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_trim)} vs Trim, \${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_ant)} vs Ano</div>
                    </div>
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Toneladas</div>
                        <div class="text-xl font-bold text-white">\${formatNumber(topAtacado.ton_atual)}</div>
                        <div class="text-sm mt-1">\${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_trim)} vs Trim, \${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_ant)} vs Ano</div>
                    </div>
                </div>
            </div>

            <div class="presentation-card">
                 <div class="flex justify-between items-end mb-4 border-b border-white/10 pb-2">
                     <h3 class="text-sm font-bold text-slate-300">Outros Atacados</h3>
                     \${outrosAtacados.length > 0 ? \`
                     <div class="text-right">
                         <div class="text-sm font-bold text-white">\${formatCurrency(totalFatOutros)}</div>
                         <div class="text-xs">\${renderVarBadge(totalFatOutros, totalFatTrimOutros)} vs Trim, \${renderVarBadge(totalFatOutros, totalFatAntOutros)} vs Ano</div>
                     </div>
                     \` : ''}
                 </div>
                 <div class="space-y-3 max-h-48 overflow-y-auto custom-scrollbar pr-2">
                    \${outrosAtacados.map(r => \`
                        <div class="flex justify-between items-center bg-black/20 p-2 rounded gap-4">
                            <span class="text-sm font-medium text-slate-300 truncate w-56" title="\${formatDim(r.dimension)}">\${formatDim(r.dimension)}</span>
                            <span class="text-sm text-white whitespace-nowrap">\${formatCurrency(r.fat_atual)}</span>
                            <span class="text-xs whitespace-nowrap">\${renderVarBadge(r.fat_atual, r.fat_trim)} vs Trim, \${renderVarBadge(r.fat_atual, r.fat_ant)} vs Ano</span>
                        </div>
                    \`).join('')}
                 </div>
            </div>
        \`;`;

if (content.includes(oldCode)) {
    fs.writeFileSync('src/js/presentation.js', content.replace(oldCode, newCode));
    console.log("Success");
} else {
    console.log("oldCode not found!");
}
