import supabase from "./supabase.js";
// presentation.js

document.addEventListener('DOMContentLoaded', async () => {
    // Initialize Swiper
    const swiper = new Swiper(".mySwiper", {
        pagination: {
            el: ".swiper-pagination",
            clickable: true,
        },
        navigation: {
            nextEl: ".swiper-button-next",
            prevEl: ".swiper-button-prev",
        },
        keyboard: {
            enabled: true,
        },
        effect: "fade", // Gives a nice presentation transition effect
        fadeEffect: {
            crossFade: true
        }
    });

    const overlay = document.getElementById('loading-overlay');
    const btnDownload = document.getElementById('download-docx-btn');

    let presentationData = null;
    let aiAnalysisText = null;

    async function loadData() {
        try {
            // Call RPC without params to get the latest period
            const { data: rpcData, error } = await supabase.rpc('get_closing_presentation_data');

            if (error) throw error;
            if (!rpcData || Object.keys(rpcData).length === 0) {
                throw new Error("Nenhum dado encontrado no banco.");
            }

            presentationData = rpcData;

            // Set header subtitle based on data returned
            if(rpcData.global && rpcData.global.length > 0) {
                const mes = rpcData.meta.curr.mes;
                const ano = rpcData.meta.curr.ano;
                const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
                document.getElementById('presentation-subtitle').textContent = `Fechamento Comercial - ${monthNames[mes-1]} ${ano}`;
            }

            renderSlides(rpcData);

            // Fetch AI
            document.getElementById('loader-text').textContent = "Gerando análise com Inteligência Artificial...";
            document.getElementById('loader-subtext').textContent = "Conectando ao modelo LLM...";

            const { data: apiKeys, error: apiError } = await supabase
                .from('api_ia')
                .select('api_key, model_name')
                .limit(1)
                .single();

            if (apiError || !apiKeys?.api_key) {
                console.warn("Chave de API não encontrada.");
                aiAnalysisText = "Análise automática não disponível. Chave de API não configurada.";
                document.getElementById('ai-analysis-content').innerHTML = `<p class="text-red-400 p-4 bg-red-900/20 rounded-lg">Análise indisponível. Verifique as configurações de IA.</p>`;
            } else {
                aiAnalysisText = await generateAiAnalysis(apiKeys.api_key, apiKeys.model_name || 'deepseek-chat', rpcData);
                document.getElementById('ai-analysis-content').innerHTML = `<div class="whitespace-pre-wrap">${aiAnalysisText}</div>`;
            }

            btnDownload.disabled = false;
        } catch (err) {
            console.error("Erro na Apresentação:", err);
            alert("Erro ao carregar dados: " + err.message);
        } finally {
            overlay.style.display = 'none';
        }
    }

    // --- RENDER LOGIC (Adapted from app.js) ---
    function renderSlides(data) {
        renderGeral(data.global);
        setupFilial(data.filiais, data.supervisores);
        renderRede(data.redes); // Actually Atacado
        setupVendedores(data.top_vendedores);
    }

    function buildCard(title, value, prevValTrim, prevValAno, isCurrency, isPercentage = false) {
        let valFmt = isCurrency ? formatCurrency(value) : (isPercentage ? formatPercent(value) : formatNumber(value));

        let varColorTrim = "text-slate-400";
        let varIconTrim = "";
        let varTextTrim = "-";

        if (prevValTrim !== undefined && prevValTrim !== null && prevValTrim !== 0) {
            const variacao = ((value - prevValTrim) / Math.abs(prevValTrim)) * 100;
            const variacaoFmt = formatPercent(variacao);
            if (variacao > 0) {
                varColorTrim = "text-emerald-400";
                varIconTrim = "↑";
                varTextTrim = `+${variacaoFmt}`;
            } else if (variacao < 0) {
                varColorTrim = "text-red-400";
                varIconTrim = "↓";
                varTextTrim = `${variacaoFmt}`;
            } else {
                varTextTrim = "0%";
            }
        } else if (prevValTrim === 0 && value > 0) {
             varColorTrim = "text-emerald-400";
             varIconTrim = "↑";
             varTextTrim = "+100%";
        }

        let varColorAno = "text-slate-400";
        let varIconAno = "";
        let varTextAno = "-";

        if (prevValAno !== undefined && prevValAno !== null && prevValAno !== 0) {
            const variacao = ((value - prevValAno) / Math.abs(prevValAno)) * 100;
            const variacaoFmt = formatPercent(variacao);
            if (variacao > 0) {
                varColorAno = "text-emerald-400";
                varIconAno = "↑";
                varTextAno = `+${variacaoFmt}`;
            } else if (variacao < 0) {
                varColorAno = "text-red-400";
                varIconAno = "↓";
                varTextAno = `${variacaoFmt}`;
            } else {
                varTextAno = "0%";
            }
        } else if (prevValAno === 0 && value > 0) {
             varColorAno = "text-emerald-400";
             varIconAno = "↑";
             varTextAno = "+100%";
        }


        return `
            <div class="presentation-card">
                <div class="metric-label">${title}</div>
                <div class="metric-value">${valFmt}</div>
                
                <div class="mt-4 grid grid-cols-2 gap-2 text-sm border-t border-white/10 pt-2">
                    <div class="flex flex-col">
                         <span class="text-xs text-slate-500 font-normal mb-0.5">vs Trim. Ant.</span>
                         <span class="font-medium ${varColorTrim} flex items-center gap-1">${varIconTrim} ${varTextTrim}</span>
                    </div>
                    <div class="flex flex-col border-l border-white/10 pl-2">
                         <span class="text-xs text-slate-500 font-normal mb-0.5">vs Ano Ant.</span>
                         <span class="font-medium ${varColorAno} flex items-center gap-1">${varIconAno} ${varTextAno}</span>
                    </div>
                </div>

            </div>
        `;
    }

    function renderGeral(geralData) {
        const container = document.getElementById('presentation-geral-cards');
        if(!geralData || geralData.length === 0) {
            container.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
            return;
        }
        const d = geralData.find(g => g.group_name === 'Geral') || geralData[0];

        container.innerHTML = `
            ${buildCard("Faturamento Total", d.fat_atual, d.fat_trim, d.fat_ant, true)}
            ${buildCard("Toneladas (Salty+Foods)", d.ton_atual, d.ton_trim, d.ton_ant, false)}
            ${buildCard("Positivação Total", d.pos_atual, d.pos_trim, d.pos_ant, false)}
        `;
    }

    function setupFilial(filialData, supervisoresData) {
        const select = document.getElementById('presentation-filial-select');
        const containerCards = document.getElementById('presentation-filial-cards');
        const tbodySup = document.getElementById('presentation-supervisor-tbody');

        if(!filialData || filialData.length === 0) {
             containerCards.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
             return;
        }

        // Populate Select
                // Get unique filiais filtering out 'Global' and grouping by dimension
        const uniqueFiliais = [...new Set(filialData.filter(f => f.group_name === 'Geral' && f.dimension !== 'Global').map(f => f.dimension))];
        select.innerHTML = uniqueFiliais.map(f => `<option value="${f}">${f}</option>`).join('');

        const renderFilial = (filialName) => {
            const fd = filialData.find(f => f.dimension === filialName) || filialData[0];
            containerCards.innerHTML = `
                ${buildCard("Faturamento", fd.fat_atual, fd.fat_trim, fd.fat_ant, true)}
                ${buildCard("Toneladas", fd.ton_atual, fd.ton_trim, fd.ton_ant, false)}
                ${buildCard("Positivação", fd.pos_atual, fd.pos_trim, fd.pos_ant, false)}
            `;

            // Supervisores
            const sups = (supervisoresData || []).filter(s => s.dimension.startsWith(filialName) && s.group_name === 'Geral');
            tbodySup.innerHTML = sups.map(s => `
                <tr class="hover:bg-white/5 transition-colors">
                    <td class="px-4 py-3 font-medium text-white">${s.dimension.split(" - ")[1] || s.dimension}</td>
                    <td class="px-4 py-3 text-right">${formatCurrency(s.fat_atual)}</td>
                    <td class="px-4 py-3 text-right">${renderVarBadge(s.fat_atual, s.fat_ant)}</td>
                    <td class="px-4 py-3 text-right">${renderVarBadge(s.fat_atual, s.fat_trim)}</td>
                    <td class="px-4 py-3 text-right">${formatNumber(s.ton_atual)}</td>
                    <td class="px-4 py-3 text-right">${formatNumber(s.pos_atual)}</td>
                </tr>
            `).join('');

            if(sups.length === 0) tbodySup.innerHTML = `<tr><td colspan="6" class="px-4 py-4 text-center text-slate-500">Nenhum supervisor encontrado.</td></tr>`;
        };

        select.addEventListener('change', (e) => renderFilial(e.target.value));
        if(uniqueFiliais.length > 0) renderFilial(uniqueFiliais[0]); // init
    }

    function renderRede(redesData) {
        const container = document.getElementById('presentation-rede-cards');
        if(!redesData || redesData.length === 0) {
            container.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
            return;
        }

        // "Rede" is now conceptually "Atacado"
        const topAtacado = redesData.sort((a,b) => b.fat_atual - a.fat_atual)[0] || redesData[0];

        container.innerHTML = `
            <div class="presentation-card bg-gradient-to-br from-fuchsia-900/40 to-transparent border-fuchsia-500/30">
                <h3 class="text-lg font-bold text-white mb-4 border-b border-fuchsia-500/30 pb-2">Top Atacado: ${topAtacado.dimension}</h3>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Faturamento</div>
                        <div class="text-xl font-bold text-white">${formatCurrency(topAtacado.fat_atual)}</div>
                        <div class="text-sm mt-1">${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_trim)} vs Trim, ${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_ant)} vs Ano</div>
                    </div>
                    <div>
                        <div class="text-xs text-slate-400 mb-1">Toneladas</div>
                        <div class="text-xl font-bold text-white">${formatNumber(topAtacado.ton_atual)}</div>
                        <div class="text-sm mt-1">${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_trim)} vs Trim, ${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_ant)} vs Ano</div>
                    </div>
                </div>
            </div>

            <div class="presentation-card">
                 <h3 class="text-sm font-bold text-slate-300 mb-4 border-b border-white/10 pb-2">Outros Atacados</h3>
                 <div class="space-y-3 max-h-48 overflow-y-auto custom-scrollbar pr-2">
                    ${redesData.filter(r => r.dimension !== topAtacado.dimension).map(r => `
                        <div class="flex justify-between items-center bg-black/20 p-2 rounded">
                            <span class="text-sm font-medium text-slate-300 truncate w-32" title="${r.dimension}">${r.dimension}</span>
                            <span class="text-sm text-white">${formatCurrency(r.fat_atual)}</span>
                            <span class="text-xs">${renderVarBadge(r.fat_atual, r.fat_trim)} vs Trim, ${renderVarBadge(r.fat_atual, r.fat_ant)} vs Ano</span>
                        </div>
                    `).join('')}
                 </div>
            </div>
        `;
    }

    function setupVendedores(vendedoresData) {
        if(!vendedoresData) return;

        const tabs = document.querySelectorAll('#top-vendedores-tabs button');
        const selectSup = document.getElementById('top-vendedores-supervisor-filter');
        const tbody = document.getElementById('presentation-vendedores-tbody');

        // Populate select
        const sups = [...new Set(vendedoresData.map(v => v.supervisor_nome).filter(Boolean))].sort();
        selectSup.innerHTML = '<option value="ALL">Todos</option>' + sups.map(s => `<option value="${s}">${s}</option>`).join('');

        let currentTab = 'fat_geral';
        let currentSup = 'ALL';

        const renderTable = () => {
            let filtered = vendedoresData;
            if(currentSup !== 'ALL') filtered = filtered.filter(v => v.supervisor_nome === currentSup);

            // Sort based on tab
            let sortKey = 'fat_atual';
            if(currentTab === 'fat_salty') sortKey = 'fat_atual_salty';
            if(currentTab === 'fat_foods') sortKey = 'fat_atual_foods';
            if(currentTab === 'ton_salty') sortKey = 'ton_atual_salty';
            if(currentTab === 'ton_foods') sortKey = 'ton_atual_foods';
            if(currentTab === 'pos_salty') sortKey = 'pos_atual_salty';
            if(currentTab === 'pos_foods') sortKey = 'pos_atual_foods';

            filtered.sort((a,b) => (b[sortKey] || 0) - (a[sortKey] || 0));
            const top10 = filtered.slice(0, 10);

            // Determine if formatting currency or number
            const isCurr = currentTab.startsWith('fat_');

            tbody.innerHTML = top10.map((v, idx) => {
                const valAtual = v[sortKey] || 0;
                let keyAntYear = sortKey.replace('_atual', '_ant');
                let keyAntTrim = sortKey.replace('_atual', '_trim');
                if(sortKey === 'fat_atual') { keyAntYear = 'fat_ant'; keyAntTrim = 'fat_trim'; }

                const valYear = v[keyAntYear] || 0;
                const valTrim = v[keyAntTrim] || 0;

                const fmt = isCurr ? formatCurrency : formatNumber;

                let medal = `<span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-white/10 text-xs font-bold text-slate-300">${idx+1}</span>`;
                if(idx === 0) medal = `🥇`;
                if(idx === 1) medal = `🥈`;
                if(idx === 2) medal = `🥉`;

                return `
                    <tr class="hover:bg-white/5 transition-colors">
                        <td class="px-4 py-3 text-center">${medal}</td>
                        <td class="px-4 py-3 font-medium text-white">
                            <div class="truncate max-w-[150px]" title="${v.vendedor}">${v.vendedor}</div>
                            <div class="text-[10px] text-slate-500">${v.supervisor_nome || 'N/A'}</div>
                        </td>
                        <td class="px-4 py-3 text-right font-semibold text-fuchsia-400">${fmt(valAtual)}</td>
                        <td class="px-4 py-3 text-right text-slate-400">${fmt(valYear)}</td>
                        <td class="px-4 py-3 text-right text-slate-400">${fmt(valTrim)}</td>
                        <td class="px-4 py-3 text-right">${renderVarBadge(valAtual, valYear)}</td>
                        <td class="px-4 py-3 text-right">${renderVarBadge(valAtual, valTrim)}</td>
                    </tr>
                `;
            }).join('');

            if(top10.length === 0) tbody.innerHTML = `<tr><td colspan="7" class="px-4 py-4 text-center text-slate-500">Nenhum vendedor encontrado.</td></tr>`;
        };

        selectSup.addEventListener('change', (e) => { currentSup = e.target.value; renderTable(); });

        tabs.forEach(btn => {
            btn.addEventListener('click', () => {
                tabs.forEach(b => {
                    b.classList.remove('bg-[#fc0100]/20', 'text-[#fc0100]', 'border-[#fc0100]/50');
                    b.classList.add('bg-white/5', 'text-slate-400', 'border-transparent');
                });
                btn.classList.add('bg-[#fc0100]/20', 'text-[#fc0100]', 'border-[#fc0100]/50');
                btn.classList.remove('bg-white/5', 'text-slate-400');
                currentTab = btn.getAttribute('data-tab');
                renderTable();
            });
        });

        renderTable();
    }

    // --- UTILS ---
    function formatCurrency(val) {
        if (!val) return 'R$ 0,00';
        return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(val);
    }
    function formatNumber(val) {
        if (!val) return '0';
        return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 }).format(val);
    }
    function formatPercent(val) {
        if (!val && val !== 0) return '0%';
        return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 1 }).format(val) + '%';
    }

    function renderVarBadge(atual, anterior) {
        if (!anterior || anterior === 0) {
             return atual > 0 ? `<span class="text-emerald-400 font-medium">↑ +100%</span>` : `<span class="text-slate-500">-</span>`;
        }
        const varPct = ((atual - anterior) / Math.abs(anterior)) * 100;
        const fmt = formatPercent(Math.abs(varPct));
        if (varPct > 0) return `<span class="text-emerald-400 font-medium">↑ ${fmt}</span>`;
        if (varPct < 0) return `<span class="text-red-400 font-medium">↓ ${fmt}</span>`;
        return `<span class="text-slate-400 font-medium">0%</span>`;
    }

    // --- AI LOGIC ---
    async function generateAiAnalysis(apiKey, modelName, data) {
        let promptText = `Atue como um analista comercial sênior e crie um roteiro executivo para uma apresentação de resultados.
Abaixo estão os dados do fechamento comercial:
- Visão Geral: Faturamento atual ${formatCurrency(data.global?.[0]?.fat_atual)}, Variacao vs Ano Anterior: ${data.global?.[0]?.fat_ant ? (((data.global[0].fat_atual - data.global[0].fat_ant)/data.global[0].fat_ant)*100).toFixed(1) : 0}%
Por favor, analise esses pontos e escreva um texto direto, profissional, com insights claros.`;

        try {
            const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                },
                body: JSON.stringify({
                    model: modelName,
                    messages: [
                        { role: "system", content: "Você é um analista executivo focado em resultados comerciais de bens de consumo." },
                        { role: "user", content: promptText }
                    ],
                    temperature: 0.5,
                    max_tokens: 800
                })
            });
            if (!response.ok) throw new Error("Erro na API da IA");
            const resData = await response.json();
            return resData.choices[0].message.content;
        } catch (e) {
            console.error(e);
            return "Erro ao comunicar com a inteligência artificial.";
        }
    }

    // --- DOCX DOWNLOAD ---
    btnDownload.addEventListener('click', async () => {
        if(!window.docx || !aiAnalysisText) return;
        try {
            const { Document, Packer, Paragraph, TextRun } = window.docx;

            const paragraphs = aiAnalysisText.split('\n').filter(p => p.trim() !== '').map(text => {
                return new Paragraph({
                    children: [ new TextRun({ text: text, size: 24 }) ],
                    spacing: { after: 200 }
                });
            });

            const doc = new Document({
                sections: [{
                    properties: {},
                    children: [
                        new Paragraph({
                            children: [ new TextRun({ text: "Resumo Executivo - Fechamento Comercial", bold: true, size: 32 }) ],
                            spacing: { after: 400 }
                        }),
                        ...paragraphs
                    ]
                }]
            });

            const blob = await Packer.toBlob(doc);
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = "Analise_Fechamento.docx";
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        } catch(e) {
            console.error(e);
            alert("Erro ao gerar arquivo Word.");
        }
    });

    // START
    loadData();
});
