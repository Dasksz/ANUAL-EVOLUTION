import supabase from "./supabase.js";

// Improve Chart.js resolution
if (typeof window !== 'undefined' && typeof window.Chart !== 'undefined') {
    window.Chart.defaults.devicePixelRatio = Math.max(window.devicePixelRatio || 1, 2);
}

// presentation.js

document.addEventListener("DOMContentLoaded", async () => {
  setupFilters();
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
      crossFade: true,
    },
  });

  const overlay = document.getElementById("loading-overlay");
  const btnDownload = document.getElementById("download-docx-btn");
  const openModalBtn = document.getElementById("open-summary-modal-btn");
  const closeModalBtn = document.getElementById("close-summary-modal-btn");
  const summaryModal = document.getElementById("summary-modal");
  const summaryModalBackdrop = document.getElementById(
    "summary-modal-backdrop",
  );
  const summaryModalContent = document.getElementById("summary-modal-content");

  // Modal open/close logic
  function openModal() {
    summaryModal.classList.remove("hidden");
    summaryModal.classList.add("flex");

    // Slight delay to allow display:flex to apply before transitioning opacity
    requestAnimationFrame(() => {
      summaryModalBackdrop.classList.remove("opacity-0");
      summaryModalBackdrop.classList.add("opacity-100");

      summaryModalContent.classList.remove("scale-95", "opacity-0");
      summaryModalContent.classList.add("scale-100", "opacity-100");
    });
  }

  function closeModal() {
    summaryModalBackdrop.classList.remove("opacity-100");
    summaryModalBackdrop.classList.add("opacity-0");

    summaryModalContent.classList.remove("scale-100", "opacity-100");
    summaryModalContent.classList.add("scale-95", "opacity-0");

    setTimeout(() => {
      summaryModal.classList.add("hidden");
      summaryModal.classList.remove("flex");
    }, 300); // Matches Tailwind transition duration
  }

  if (openModalBtn) openModalBtn.addEventListener("click", openModal);
  if (closeModalBtn) closeModalBtn.addEventListener("click", closeModal);
  if (summaryModalBackdrop)
    summaryModalBackdrop.addEventListener("click", closeModal);

  const closeRankingBtn = document.getElementById("close-ranking-modal-btn");
  const rankingBackdrop = document.getElementById("ranking-modal-backdrop");
  if (closeRankingBtn) closeRankingBtn.addEventListener("click", closeRankingModal);
  if (rankingBackdrop) rankingBackdrop.addEventListener("click", closeRankingModal);

  let presentationData = null;
  let aiAnalysisText = null;

  async function loadData() {
    try {
      // Call RPC without params to get the latest period

      const urlParams = new URLSearchParams(window.location.search);
      const p_ano = urlParams.get('ano') || null;
      const p_mes = urlParams.get('mes') || null;

      const { data: rpcData, error } = await supabase.rpc(
        "get_closing_presentation_data",
        { p_ano, p_mes }
      );


      if (error) throw error;
      if (!rpcData || Object.keys(rpcData).length === 0) {
        throw new Error("Nenhum dado encontrado no banco.");
      }

      window.currentPresentationData = rpcData;

      // Set header subtitle based on data returned
      if (rpcData.global && rpcData.global.length > 0) {
        const mes = rpcData.meta.curr.mes;
        const ano = rpcData.meta.curr.ano;
        const monthNames = [
          "Janeiro",
          "Fevereiro",
          "Março",
          "Abril",
          "Maio",
          "Junho",
          "Julho",
          "Agosto",
          "Setembro",
          "Outubro",
          "Novembro",
          "Dezembro",
        ];
        document.getElementById("presentation-subtitle").textContent =
          `Fechamento Comercial - ${monthNames[mes - 1]} ${ano}`;
      }

      renderSlides(rpcData);
      
      // Init new slides
      if (typeof window.renderCategoriasDispute === 'function') {
          window.renderCategoriasDispute(rpcData, 'geral');
      }

      if (typeof window.initLojaPerfeitaSlide === 'function') {
          const m = rpcData.meta.curr.mes;
          const a = rpcData.meta.curr.ano;
          window.initLojaPerfeitaSlide(a, m);
      }


      // Fetch AI
      document.getElementById("loader-text").textContent =
        "Gerando análise com Inteligência Artificial...";
      document.getElementById("loader-subtext").textContent =
        "Conectando ao modelo LLM...";

      const { data: apiKeys, error: apiError } = await supabase
        .from("api_ia")
        .select("api_key, model_name")
        .limit(1)
        .single();

      if (apiError || !apiKeys?.api_key) {
        console.warn("Chave de API não encontrada.");
        aiAnalysisText =
          "Análise automática não disponível. Chave de API não configurada.";
        document.getElementById("ai-analysis-content").innerHTML =
          `<p class="text-red-400 p-4 bg-red-900/20 rounded-lg">Análise indisponível. Verifique as configurações de IA.</p>`;
      } else {
        aiAnalysisText = await generateAiAnalysis(
          apiKeys.api_key,
          apiKeys.model_name || "deepseek-chat",
          rpcData,
        );
        document.getElementById("ai-analysis-content").innerHTML =
          `<div class="whitespace-pre-wrap">${aiAnalysisText}</div>`;
      }

      btnDownload.disabled = false;
      if (openModalBtn) openModalBtn.classList.remove("hidden");
    } catch (err) {
      console.error("Erro na Apresentação:", err);
      alert("Erro ao carregar dados: " + err.message);
    } finally {
      overlay.style.display = "none";
    }
  }


  // --- Categorias Dispute Logic ---
  window.renderCategoriasDispute = function(data, activeMetric) {
    if (!data.categorias_disputa) return;
    
    // Growth calculation
    let growthData = [];
    data.categorias_disputa.forEach(d => {
        let fatGrowth = d.fat_trim > 0 ? ((d.fat_atual - d.fat_trim) / d.fat_trim) * 100 : (d.fat_atual > 0 ? 100 : 0);
        let tonGrowth = d.ton_trim > 0 ? ((d.ton_atual - d.ton_trim) / d.ton_trim) * 100 : (d.ton_atual > 0 ? 100 : 0);
        let posGrowth = d.pos_trim > 0 ? ((d.pos_atual - d.pos_trim) / d.pos_trim) * 100 : (d.pos_atual > 0 ? 100 : 0);
        
        let score = 0;
        if (activeMetric === 'faturamento') score = fatGrowth;
        else if (activeMetric === 'tonelada') score = tonGrowth;
        else if (activeMetric === 'posituacao') score = posGrowth;
        else score = fatGrowth + tonGrowth + posGrowth; // Geral
        
        growthData.push({ ...d, fatGrowth, tonGrowth, posGrowth, score });
    });

    // KPI Calc (Salty)
    let saltyShark = data.kpi_salty?.find(k => k.equipe === 'SHARK')?.clientes_salty || 0;
    let saltyAguia = data.kpi_salty?.find(k => k.equipe === 'ÁGUIA')?.clientes_salty || 0;

    // Cross check categories share (Faturamento base for general share dominance)
    let sharkDom = 0;
    let aguiaDom = 0;
    
    // Group by category to find total
    let catTotals = {};
    data.categorias_disputa.forEach(d => {
        if (!catTotals[d.categoria]) catTotals[d.categoria] = { totalFat: 0 };
        catTotals[d.categoria].totalFat += Number(d.fat_atual);
    });
    
    let shareRankings = [];

    Object.keys(catTotals).forEach(cat => {
        let fatShark = Number(data.categorias_disputa.find(d => d.categoria === cat && d.equipe === 'SHARK')?.fat_atual || 0);
        let fatAguia = Number(data.categorias_disputa.find(d => d.categoria === cat && d.equipe === 'ÁGUIA')?.fat_atual || 0);
        let total = catTotals[cat].totalFat;
        
        if (total > 0) {
             let pShark = (fatShark / total) * 100;
             let pAguia = (fatAguia / total) * 100;
             
             if (pShark > 50) sharkDom++;
             if (pAguia > 50) aguiaDom++;
             
             shareRankings.push({
                 categoria: cat,
                 pShark,
                 pAguia,
                 total
             });
        }
    });
    
    shareRankings.sort((a,b) => b.total - a.total); // Sort by biggest category total

    const kpiDiv = document.getElementById("categorias-kpis");
    if(kpiDiv) {
        kpiDiv.innerHTML = `
            <div class="bg-blue-900/20 border border-blue-500/30 p-3 rounded-lg text-center">
               <div class="text-[10px] text-blue-400 font-bold uppercase mb-1">Clientes Salty (Shark)</div>
               <div class="text-xl font-bold text-white">${saltyShark}</div>
            </div>
            <div class="bg-blue-900/20 border border-blue-500/30 p-3 rounded-lg text-center">
               <div class="text-[10px] text-blue-400 font-bold uppercase mb-1">Domínio Categorias (Shark)</div>
               <div class="text-xl font-bold text-white">${sharkDom}</div>
            </div>
            <div class="bg-red-900/20 border border-red-500/30 p-3 rounded-lg text-center">
               <div class="text-[10px] text-red-400 font-bold uppercase mb-1">Domínio Categorias (Águia)</div>
               <div class="text-xl font-bold text-white">${aguiaDom}</div>
            </div>
            <div class="bg-red-900/20 border border-red-500/30 p-3 rounded-lg text-center">
               <div class="text-[10px] text-red-400 font-bold uppercase mb-1">Clientes Salty (Águia)</div>
               <div class="text-xl font-bold text-white">${saltyAguia}</div>
            </div>
        `;
    }
    
    const shareDiv = document.getElementById("categorias-share-ranking");
    if(shareDiv) {
        shareDiv.innerHTML = shareRankings.map(s => `
            <div class="flex items-center text-xs mb-1 shrink-0">
                <div class="w-1/4 text-white font-bold tracking-wide uppercase text-[10px] truncate pr-2" title="${s.categoria}">${s.categoria}</div>
                <div class="w-3/4 flex h-4 rounded-sm overflow-hidden bg-white/5 border border-white/5 relative shadow-inner">
                    <div class="h-full bg-blue-500 flex items-center pl-2" style="width: ${s.pShark}%">
                        ${s.pShark > 15 ? `<span class="text-[9px] font-bold text-white shadow-black drop-shadow-md">${s.pShark.toFixed(1)}%</span>` : ''}
                    </div>
                    <div class="h-full bg-[#ef4444] flex items-center justify-end pr-2" style="width: ${s.pAguia}%">
                        ${s.pAguia > 15 ? `<span class="text-[9px] font-bold text-white shadow-black drop-shadow-md">${s.pAguia.toFixed(1)}%</span>` : ''}
                    </div>
                </div>
            </div>
        `).join('');
    }

    if (data.vendedores_categorias) {
        let sortedVendors = [...data.vendedores_categorias].sort((a, b) => {
            if (activeMetric === 'faturamento') {
                return b.faturamento - a.faturamento;
            } else if (activeMetric === 'tonelada') {
                return b.tonelada - a.tonelada;
            } else if (activeMetric === 'posituacao') {
                return b.posituacoes - a.posituacoes;
            } else {
                if (b.categorias_distintas !== a.categorias_distintas) {
                    return b.categorias_distintas - a.categorias_distintas;
                }
                return b.faturamento - a.faturamento;
            }
        });

        let topShark = sortedVendors.filter(v => v.equipe === 'SHARK').slice(0, 3);
        let topAguia = sortedVendors.filter(v => v.equipe === 'ÁGUIA').slice(0, 3);

        const renderVendor = (v, i, teamClass) => {
            let primaryValue = '';
            if (activeMetric === 'faturamento') {
                primaryValue = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v.faturamento);
            } else if (activeMetric === 'tonelada') {
                primaryValue = (v.tonelada || 0).toFixed(2) + ' <span class="text-[10px] text-slate-500 font-normal">Ton</span>';
            } else if (activeMetric === 'posituacao') {
                primaryValue = (v.posituacoes || 0) + ' <span class="text-[10px] text-slate-500 font-normal">Pos</span>';
            } else {
                primaryValue = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(v.faturamento);
            }
            
            return `
            <div class="flex items-center justify-between p-2 rounded-lg bg-${teamClass}-900/20 border border-${teamClass}-500/20 shadow-sm shadow-${teamClass}-900/30">
                <div class="flex items-center gap-3">
                    <div class="flex items-center justify-center w-6 h-6 rounded-full bg-[#131217] text-white text-xs font-bold border border-${teamClass}-500/30">${i + 1}</div>
                    <span class="text-white font-semibold text-xs tracking-wide truncate max-w-[120px] uppercase" title="${v.vendedor.toUpperCase()}">${v.vendedor.toUpperCase()}</span>
                </div>
                <div class="flex flex-col items-end">
                    <span class="text-white text-xs font-bold">${activeMetric === 'geral' ? v.categorias_distintas + ' <span class="text-slate-500 text-[10px] font-normal">Cats</span>' : ''}</span>
                    <span class="text-emerald-400 text-xs font-semibold">${primaryValue}</span>
                </div>
            </div>
        `};

        const divShark = document.getElementById("categorias-sellers-shark");
        const divAguia = document.getElementById("categorias-sellers-aguia");
        if (divShark) divShark.innerHTML = topShark.map((v, i) => renderVendor(v, i, 'blue')).join('');
        if (divAguia) divAguia.innerHTML = topAguia.map((v, i) => renderVendor(v, i, 'red')).join('');
    }

    // Growth Ranking
    growthData.sort((a,b) => b.score - a.score);
    const growthDiv = document.getElementById("categorias-growth-ranking");
    if(growthDiv) {
        growthDiv.innerHTML = growthData.map(g => {
            const teamColorClass = g.equipe === 'SHARK' ? 'text-blue-400' : 'text-red-400';
            
            const formatGrowth = (val) => {
                const color = val > 0 ? 'text-emerald-400' : (val < 0 ? 'text-red-400' : 'text-slate-400');
                const sign = val > 0 ? '+' : '';
                return `<span class="${color} font-bold text-[11px]">${sign}${val.toFixed(1)}%</span>`;
            };

            return `
            <div class="flex items-center justify-between border-b border-white/5 pb-2 last:border-0 last:pb-0 shrink-0">
                <div class="flex flex-col w-1/3">
                    <span class="text-white font-bold uppercase text-[10px] truncate" title="${g.categoria}">${g.categoria}</span>
                    <span class="${teamColorClass} text-[9px] font-black uppercase tracking-wider">${g.equipe}</span>
                </div>
                <div class="flex w-2/3 justify-between text-[10px] text-right pl-4">
                    <div class="flex flex-col items-end w-1/3">
                        <span class="text-slate-500 text-[8px] uppercase">Fat.</span>
                        ${formatGrowth(g.fatGrowth)}
                    </div>
                    <div class="flex flex-col items-end w-1/3">
                        <span class="text-slate-500 text-[8px] uppercase">Ton.</span>
                        ${formatGrowth(g.tonGrowth)}
                    </div>
                    <div class="flex flex-col items-end w-1/3">
                        <span class="text-slate-500 text-[8px] uppercase">Pos.</span>
                        ${formatGrowth(g.posGrowth)}
                    </div>
                </div>
            </div>
            `;
        }).join('');
    }
    
    const metricLabel = document.getElementById("growth-metric-label");
    if (metricLabel) {
        metricLabel.textContent = `Métrica: ${activeMetric.charAt(0).toUpperCase() + activeMetric.slice(1)}`;
    }
  }; // End of renderCategoriasDispute


  });

  // START
  loadData();
});
