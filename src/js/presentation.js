import supabase from "./supabase.js";
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
      const { data: rpcData, error } = await supabase.rpc(
        "get_closing_presentation_data",
      );

      if (error) throw error;
      if (!rpcData || Object.keys(rpcData).length === 0) {
        throw new Error("Nenhum dado encontrado no banco.");
      }

      presentationData = rpcData;

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

  // --- RENDER LOGIC (Adapted from app.js) ---
    function renderSlides(data) {
    globalVendedoresData = data.top_vendedores || [];
    renderGeral(data.global);

    const targetYear = data.meta?.curr?.ano || new Date().getFullYear();
    const targetMonthIdx =
      (data.meta?.curr?.mes || new Date().getMonth() + 1) - 1;
    setupFilial(data.filiais, data.supervisores);
    renderRede(data.redes, data.meta, data.global); // Actually Atacado
    setupVendedores(data.top_vendedores);
  }

  function buildCard(
    title,
    value,
    prevValTrim,
    prevValAno,
    isCurrency,
    isPercentage = false,
  ) {
    let valFmt = isCurrency
      ? formatCurrency(value)
      : isPercentage
        ? formatPercent(value)
        : formatNumber(value);

    let varColorTrim = "text-slate-400";
    let varIconTrim = "";
    let varTextTrim = "-";

    if (
      prevValTrim !== undefined &&
      prevValTrim !== null &&
      prevValTrim !== 0
    ) {
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
            <div class="presentation-card" ${title === 'Devoluções' ? 'onclick="window.openRankingModal(\'dev\')" style="cursor:pointer"' : ""} ${title === 'Bonificações' ? 'onclick="window.openRankingModal(\'bon\')" style="cursor:pointer"' : ""}>
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
    if (geralData) globalGeralData = geralData;
    if (presentationData && presentationData.chart_data) {
        const targetYear = presentationData.meta?.curr?.ano || new Date().getFullYear();
        const targetMonthIdx = (presentationData.meta?.curr?.mes || new Date().getMonth() + 1) - 1;
        renderEvolutionChart(presentationData.chart_data, targetYear, targetMonthIdx);
    }
    const containerTop = document.getElementById("presentation-geral-cards-top");
    const containerMiddle = document.getElementById("presentation-geral-cards-middle");
    
    if (!globalGeralData || globalGeralData.length === 0) {
      containerTop.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
      containerMiddle.innerHTML = '';
      return;
    }
    const d = globalGeralData.find((g) => g.group_name === currentGeralFilter) || globalGeralData[0];

    containerTop.innerHTML = `
            ${buildCard("Faturamento Total", d.fat_atual, d.fat_trim, d.fat_ant, true)}
            ${buildCard(currentGeralFilter === 'Geral' ? "Toneladas (Salty+Foods)" : `Toneladas ${currentGeralFilter}`, d.ton_atual, d.ton_trim, d.ton_ant, false)}
            ${buildCard("Positivação Total", d.pos_atual, d.pos_trim, d.pos_ant, false)}
        `;

    containerMiddle.innerHTML = `
            ${buildCard("Devoluções", d.dev_atual, d.dev_trim, d.dev_ant, true)}
            ${buildCard("Bonificações", d.bonificacao_atual, d.bonificacao_trim, d.bonificacao_ant, true)}
        `;
  }

  function renderEvolutionChart(chartData, targetYear, targetMonthIndex) {
    const canvas = document.getElementById("presentation-evolution-chart");
    if (!canvas || !chartData || chartData.length === 0) return;

    // format chartData for current and previous year
    const prevYear = targetYear - 1;
    const months = [
      "Jan",
      "Fev",
      "Mar",
      "Abr",
      "Mai",
      "Jun",
      "Jul",
      "Ago",
      "Set",
      "Out",
      "Nov",
      "Dez",
    ];

    const currData = new Array(12).fill(0);
    const prevData = new Array(12).fill(0);

    chartData
      .filter((d) => d.group_name === currentGeralFilter)
      .forEach((d) => {
      const mIdx = d.mes - 1;
      if (d.ano === targetYear && mIdx >= 0 && mIdx < 12)
        currData[mIdx] += Number(d.faturamento);
      if (d.ano === prevYear && mIdx >= 0 && mIdx < 12)
        prevData[mIdx] += Number(d.faturamento);
    });

    // Find best month of current year (only considering up to target month to be safe, or all available)
    let bestMonthIdx = -1;
    let maxVal = -1;
    currData.forEach((val, idx) => {
      if (val > maxVal) {
        maxVal = val;
        bestMonthIdx = idx;
      }
    });

    // If best month is found, we can place the star on target month if requested, but instructions said:
    // "ícone de estrela acima da coluna do melhor mês do ano atual que, para o cenário atual, será posicionado no próprio mês em análise."
    // Interpreting as: The star goes on the best month. If the instruction specifically meant forcing it to the target month, we will set it to target month, but usually it means dynamic best month. Let's stick to dynamically calculating the best month, or if forced to current month:
    // Let's force it to target month if it's strictly requested, but "melhor mês do ano atual" implies a calculation. Let's use the calculated best month.

    const ctx = canvas.getContext("2d");

    // Custom plugin to draw star
    const drawStarPlugin = {
      id: "drawStarPlugin",
      afterDatasetsDraw(chart, args, pluginOptions) {
        const {
          ctx,
          data,
          chartArea: { top },
          scales: { x, y },
        } = chart;
        ctx.save();

        const meta = chart.getDatasetMeta(0); // dataset 0 is current year
        if (bestMonthIdx >= 0 && meta.data[bestMonthIdx]) {
          const bar = meta.data[bestMonthIdx];
          const xPos = bar.x;
          const yPos = bar.y - 15; // slightly above bar

          ctx.font = "20px Arial";
          ctx.textAlign = "center";
          ctx.textBaseline = "middle";
          // ctx.fillStyle = '#facc15';
          ctx.fillText("⭐", xPos, yPos);
        }
        ctx.restore();
      },
    };

    if (window.presentationEvolutionChartInstance) {
      window.presentationEvolutionChartInstance.destroy();
    }

    // Custom colors for current month highlight
    const bgColorsCurr = currData.map((_, i) =>
      i === targetMonthIndex ? "#d946ef" : "#a21caf",
    ); // fuchsia highlight vs purple

    window.presentationEvolutionChartInstance = new Chart(ctx, {
      type: "bar",
      data: {
        labels: months,
        datasets: [
          {
            label: `Ano Atual (${targetYear})`,
            data: currData,
            backgroundColor: bgColorsCurr,
            borderRadius: 4,
            borderSkipped: false,
          },
          {
            label: `Ano Anterior (${prevYear})`,
            data: prevData,
            backgroundColor: "#334155", // slate-700
            borderRadius: 4,
            borderSkipped: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            labels: { color: "#cbd5e1" },
          },
          tooltip: {
            callbacks: {
              label: (context) => formatCurrency(context.raw),
            },
          },
          datalabels: { display: false }, // disable datalabels if plugin is loaded globally
        },
        scales: {
          x: {
            ticks: { color: "#94a3b8" },
            grid: { display: false },
          },
          y: {
            ticks: {
              color: "#94a3b8",
              callback: (val) => {
                if (val >= 1000000) return (val / 1000000).toFixed(1) + "M";
                if (val >= 1000) return (val / 1000).toFixed(0) + "k";
                return val;
              },
            },
            grid: { color: "rgba(255, 255, 255, 0.05)" },
          },
        },
      },
      plugins: [drawStarPlugin],
    });
  }

  function setupFilial(filialData, supervisoresData) {
    if (filialData) globalFilialData = filialData;
    const categoriasData = presentationData.categorias || [];
    const select = document.getElementById("presentation-filial-select");
    const containerCards = document.getElementById("presentation-filial-cards");
    const tbodySup = document.getElementById("presentation-supervisor-tbody");

    if (!filialData || filialData.length === 0) {
      containerCards.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
      return;
    }

    // Populate Select
    // Get unique filiais filtering out 'Global' and grouping by dimension
    const uniqueFiliais = [
      ...new Set(
        filialData
          .filter((f) => f.group_name === "Geral" && f.dimension !== "Global")
          .map((f) => f.dimension),
      ),
    ];
    select.innerHTML = uniqueFiliais
      .map((f) => `<option value="${f}">${f}</option>`)
      .join("");

    const renderFilial = (filialName) => {
      currentFilialSelected = filialName;
      const fd =
        globalFilialData.find((f) => f.dimension === filialName && f.group_name === currentFilialFilter) || globalFilialData[0];
      containerCards.innerHTML = `
                ${buildCard("Faturamento", fd.fat_atual, fd.fat_trim, fd.fat_ant, true)}
                ${buildCard("Toneladas", fd.ton_atual, fd.ton_trim, fd.ton_ant, false)}
                ${buildCard("Positivação", fd.pos_atual, fd.pos_trim, fd.pos_ant, false)}
            `;

      // Supervisores
      const sups = (supervisoresData || []).filter(
        (s) => s.dimension.startsWith(filialName) && s.group_name === currentFilialFilter,
      );
      tbodySup.innerHTML = sups
        .map(
          (s) => `
                <tr class="hover:bg-white/5 transition-colors">
                    <td class="px-4 py-3 font-medium text-white">${s.dimension.split(" - ")[1] || s.dimension}</td>
                    <td class="px-4 py-3">${formatCurrency(s.fat_atual)}</td>
                    <td class="px-4 py-3">${renderVarBadge(s.fat_atual, s.fat_ant)}</td>
                    <td class="px-4 py-3">${renderVarBadge(s.fat_atual, s.fat_trim)}</td>
                    <td class="px-4 py-3">${formatNumber(s.ton_atual)}</td>
                    <td class="px-4 py-3">${formatNumber(s.pos_atual)}</td>
                </tr>
            `,
        )
        .join("");

      // --- Categorias ---
      const renderCategoryCircle = (catName, isSalty) => {
        // Find category data for this branch
        const cd = categoriasData.find(
          (c) => c.filial === filialName && c.cat_name === catName,
        );
        const fatAtual = cd ? Number(cd.fat_atual) : 0;
        const fatTrim = cd ? Number(cd.fat_trim) : 0;

        // Meta base: 100% = Média do último trimestre + 15%
        const meta = fatTrim * 1.15;
        let pct = 0;
        if (meta > 0) {
          pct = (fatAtual / meta) * 100;
        } else if (fatAtual > 0) {
          pct = 100; // if no history but has sales
        }

        // UI clamps stroke array to 100 max visually, but text shows actual
        const strokeArray = Math.min(pct, 100).toFixed(1);
        const isUnder = pct < 100;

        const cssClass = isUnder ? "below-target" : isSalty ? "salty" : "foods";
        const displayName = catName;

        return `
                    <div class="circular-chart-container" tabindex="0">
                        <span class="text-[10px] font-bold text-slate-300 mb-2 truncate w-full text-center">${displayName}</span>
                        <svg viewBox="0 0 36 36" class="circular-chart ${cssClass}">
                            <path class="circle-bg"
                                d="M18 2.0845
                                a 15.9155 15.9155 0 0 1 0 31.831
                                a 15.9155 15.9155 0 0 1 0 -31.831"
                            />
                            <path class="circle"
                                stroke-dasharray="${strokeArray}, 100"
                                d="M18 2.0845
                                a 15.9155 15.9155 0 0 1 0 31.831
                                a 15.9155 15.9155 0 0 1 0 -31.831"
                            />
                            <text x="18" y="20.35" class="percentage">${pct.toFixed(0)}%</text>
                        </svg>
                        <div class="cat-tooltip">Fat: ${formatCurrency(fatAtual)}</div>
                    </div>
                `;
      };

      const saltyContainer = document.getElementById("presentation-cat-salty");
      const foodsContainer = document.getElementById("presentation-cat-foods");

      if (saltyContainer) {
        saltyContainer.innerHTML =
          renderCategoryCircle("CHEETOS", true) +
          renderCategoryCircle("FANDANGOS", true) +
          renderCategoryCircle("DORITOS", true) +
          renderCategoryCircle("CEBOLITOS", true) +
          renderCategoryCircle("RUFFLES", true);
      }
      if (foodsContainer) {
        foodsContainer.innerHTML =
          renderCategoryCircle("TODDY", false) +
          renderCategoryCircle("TODDYNHO", false) +
          renderCategoryCircle("QUAKER", false) +
          renderCategoryCircle("KEROCOCO", false);
      }

      if (sups.length === 0)
        tbodySup.innerHTML = `<tr><td colspan="6" class="px-4 py-4 text-center text-slate-500">Nenhum supervisor encontrado.</td></tr>`;
    };

    select.addEventListener("change", (e) => renderFilial(e.target.value));
    if (uniqueFiliais.length > 0) renderFilial(uniqueFiliais[0]); // init
  }

  function renderRede(redesData, meta, globalData) {
    const container = document.getElementById("presentation-rede-cards");
    if (!redesData || redesData.length === 0) {
      container.innerHTML = '<p class="text-slate-400">Sem dados.</p>';
      return;
    }

    // Helper to remove "Rede: " prefix
    const formatDim = (dim) => (dim ? dim.replace(/^Rede:\s*/i, "") : dim);

    // Context formatting
    const monthNames = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
    const targetMonthIdx = meta?.curr?.mes ? meta.curr.mes - 1 : new Date().getMonth();
    const targetYear = meta?.curr?.ano || new Date().getFullYear();
    const monthName = monthNames[targetMonthIdx];

    // Global aggregations from ALL redes
    const totalFatGlobal = redesData.reduce((sum, r) => sum + (r.fat_atual || 0), 0);
    const totalFatTrimGlobal = redesData.reduce((sum, r) => sum + (r.fat_trim || 0), 0);
    const totalTonGlobal = redesData.reduce((sum, r) => sum + (r.ton_atual || 0), 0);
    const totalTonTrimGlobal = redesData.reduce((sum, r) => sum + (r.ton_trim || 0), 0);
    const formatTotalApprox = (val) => val >= 1000 ? `~R$ ${Math.floor(val/1000)}K` : `~R$ ${val}`;
    
    // Sort logic for top crescimento
    const calcVarPct = (atual, trim) => {
      if (!trim || trim === 0) return atual > 0 ? 100 : 0;
      return ((atual - trim) / Math.abs(trim)) * 100;
    };
    
    const redesCrescimento = [...redesData].sort((a, b) => calcVarPct(b.fat_atual, b.fat_trim) - calcVarPct(a.fat_atual, a.fat_trim)).slice(0, 3);
    
    // Find absolute top atacado
    const topAtacado = [...redesData].sort((a, b) => (b.fat_atual || 0) - (a.fat_atual || 0))[0] || redesData[0];
    const outrosAtacados = redesData.filter((r) => r.dimension !== topAtacado.dimension);

    const totalFatOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_atual || 0), 0);
    const totalFatTrimOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_trim || 0), 0);
    const totalFatAntOutros = outrosAtacados.reduce((sum, r) => sum + (r.fat_ant || 0), 0);

    const topNames = outrosAtacados.length > 0 ? `(${formatDim(topAtacado.dimension)} + Outros Atacados)` : `(${formatDim(topAtacado.dimension)})`;

    container.innerHTML = `
      <!-- Top Row: 4 Cards -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-4">
          <!-- Total Faturado -->
          <div class="presentation-card relative overflow-hidden group">
              <div class="absolute top-0 left-0 w-1 h-full bg-fuchsia-500 rounded-l-lg"></div>
              <div class="text-xs text-slate-400 font-bold uppercase mb-2 tracking-wider">TOTAL FATURADO GLOBAL (${monthName} ${targetYear})</div>
              <div class="flex justify-between items-end mb-2">
                 <div>
                    <div class="text-2xl lg:text-3xl font-extrabold text-white">${formatCurrency(totalFatGlobal)}</div>
                    <div class="text-xs text-slate-500 mt-1">${topNames}</div>
                 </div>
                 <div class="text-right">
                    <div class="text-xl lg:text-2xl font-bold ${calcVarPct(totalFatGlobal, totalFatTrimGlobal) > 0 ? 'text-emerald-400' : 'text-red-400'}">
                        ${calcVarPct(totalFatGlobal, totalFatTrimGlobal) > 0 ? '↑' : '↓'} ${formatPercent(Math.abs(calcVarPct(totalFatGlobal, totalFatTrimGlobal)))}
                    </div>
                    <div class="text-[10px] text-slate-500">vs Mês Anterior</div>
                 </div>
              </div>
              <div class="mt-4 bg-white/5 rounded px-3 py-2 text-sm text-slate-400 font-medium">
                  Valor Aproximado: ${formatTotalApprox(totalFatGlobal)}
              </div>
          </div>
          
          <!-- Total Toneladas -->
          <div class="presentation-card relative overflow-hidden group">
              <div class="absolute top-0 left-0 w-1 h-full bg-purple-500 rounded-l-lg"></div>
              <div class="text-xs text-slate-400 font-bold uppercase mb-2 tracking-wider">TOTAL TONELADAS GLOBAL</div>
              <div class="flex justify-between items-end mb-2">
                 <div>
                    <div class="text-2xl lg:text-3xl font-extrabold text-white">${formatNumber(totalTonGlobal)} <span class="text-base lg:text-lg font-medium text-slate-400">tons</span></div>
                    <div class="text-xs text-slate-500 mt-1">Estimado total, e.g.</div>
                 </div>
                 <div class="text-right">
                    <div class="text-xl lg:text-2xl font-bold ${calcVarPct(totalTonGlobal, totalTonTrimGlobal) > 0 ? 'text-emerald-400' : 'text-red-400'}">
                        ${calcVarPct(totalTonGlobal, totalTonTrimGlobal) > 0 ? '↑' : '↓'} ${formatPercent(Math.abs(calcVarPct(totalTonGlobal, totalTonTrimGlobal)))}
                    </div>
                    <div class="text-[10px] text-slate-500">vs Mês Anterior</div>
                 </div>
              </div>
          </div>

          <!-- Top Redes Crescimento -->
          <div class="presentation-card flex flex-col justify-center">
              <div class="text-xs text-slate-400 font-bold uppercase mb-4 tracking-wider">TOP REDES POR CRESCIMENTO</div>
              <div class="space-y-3">
                  ${redesCrescimento.map((r, i) => `
                      <div class="flex justify-between items-center text-sm font-medium">
                          <span class="text-white truncate">${i + 1}. ${formatDim(r.dimension)}</span>
                          <span class="${calcVarPct(r.fat_atual, r.fat_trim) > 0 ? 'text-emerald-400' : 'text-red-400'}">
                              ${calcVarPct(r.fat_atual, r.fat_trim) > 0 ? '+' : ''}${formatPercent(calcVarPct(r.fat_atual, r.fat_trim))}
                          </span>
                      </div>
                  `).join('')}
              </div>
          </div>

          <!-- Decorative Image -->
          <div class="hidden lg:block h-full lg:h-[260px] w-full rounded-xl border border-white/10 shadow-lg overflow-hidden">
              <img src="https://centraldovarejo.com.br/wp-content/uploads/2023/12/woman-at-work-putting-boxes-on-the-shelves-beside-2023-11-27-05-07-58-utc.jpg" alt="Resultados Atacado" class="w-full h-full object-cover object-center opacity-80 mix-blend-luminosity hover:mix-blend-normal transition-all duration-500">
          </div>
      </div>

      <!-- Bottom Row: 2 Cards -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <!-- Top Atacado -->
            <div class="presentation-card bg-gradient-to-br from-fuchsia-900/20 to-transparent border-fuchsia-500/30 flex flex-col justify-center">
                <h3 class="text-sm font-bold text-slate-300 mb-4 uppercase tracking-wider">${formatDim(topAtacado.dimension)}</h3>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <div class="text-xs text-slate-500 mb-1">Faturamento</div>
                        <div class="text-xl font-bold text-white">${formatCurrency(topAtacado.fat_atual)}</div>
                        <div class="text-xs mt-1">${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_trim)} vs Trim, ${renderVarBadge(topAtacado.fat_atual, topAtacado.fat_ant)} vs Ano</div>
                    </div>
                    <div>
                        <div class="text-xs text-slate-500 mb-1">Tonelada</div>
                        <div class="text-xl font-bold text-white">${formatNumber(topAtacado.ton_atual)}</div>
                        <div class="text-xs mt-1">${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_trim)} vs Trim, ${renderVarBadge(topAtacado.ton_atual, topAtacado.ton_ant)} vs Ano</div>
                    </div>
                </div>
            </div>

            <!-- Outros Atacados -->
            <div class="presentation-card flex flex-col">
                 <div class="flex justify-between items-end mb-4 border-b border-white/10 pb-2">
                     <h3 class="text-sm font-bold text-slate-300">Outros Atacados</h3>
                     ${
                       outrosAtacados.length > 0
                         ? `
                     <div class="text-right">
                         <div class="text-sm font-bold text-white">${formatCurrency(totalFatOutros)}</div>
                         <div class="text-xs">${renderVarBadge(totalFatOutros, totalFatTrimOutros)} vs Trim, ${renderVarBadge(totalFatOutros, totalFatAntOutros)} vs Ano</div>
                     </div>
                     `
                         : ""
                     }
                 </div>
                 <div class="space-y-3 max-h-48 overflow-y-auto custom-scrollbar pr-2">
                    ${outrosAtacados
                      .map(
                        (r) => `
                        <div class="flex justify-between items-center bg-black/20 p-2 rounded gap-4 hover:bg-black/40 transition-colors">
                            <span class="text-sm font-medium text-slate-300 truncate w-40" title="${formatDim(r.dimension)}">${formatDim(r.dimension)}</span>
                            <span class="text-sm text-white whitespace-nowrap">${formatCurrency(r.fat_atual)}</span>
                            <span class="text-xs whitespace-nowrap text-right flex-shrink-0">${renderVarBadge(r.fat_atual, r.fat_trim)} vs Trim, ${renderVarBadge(r.fat_atual, r.fat_ant)} vs Ano</span>
                        </div>
                    `,
                      )
                      .join("")}
                 </div>
            </div>
      </div>
    `;
  }

  // --- Modal Ranking Logic ---
  let globalVendedoresData = [];
  let globalGeralData = [];
  let currentGeralFilter = 'Geral';
  let globalFilialData = [];
  let currentFilialFilter = 'Geral';
  let currentFilialSelected = null;

  // --- Filters Event Listeners ---
  function setupFilters() {
    const geralButtons = document.querySelectorAll('#presentation-geral-filters button');
    geralButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const filter = btn.getAttribute('data-filter');
        if (currentGeralFilter === filter) {
          currentGeralFilter = 'Geral'; // Toggle off
        } else {
          currentGeralFilter = filter;
        }

        // Update styling
        geralButtons.forEach(b => {
          b.classList.remove('bg-fuchsia-600', 'text-white', 'border-fuchsia-400');
          b.classList.add('bg-[#fc0100]/20', 'text-[#fc0100]', 'border-[#fc0100]/50');
        });
        if (currentGeralFilter !== 'Geral') {
             btn.classList.remove('bg-[#fc0100]/20', 'text-[#fc0100]', 'border-[#fc0100]/50');
             btn.classList.add('bg-fuchsia-600', 'text-white', 'border-fuchsia-400');
        }

        // Re-render
        renderGeral(globalGeralData);
      });
    });
  }

  // Helpers
  window.openRankingModal = openRankingModal;
  function openRankingModal(metric) {
    if (!globalVendedoresData || globalVendedoresData.length === 0) return;

    const modal = document.getElementById("ranking-modal");
    const backdrop = document.getElementById("ranking-modal-backdrop");
    const content = document.getElementById("ranking-modal-content");
    const title = document.getElementById("ranking-modal-title");
    const tbody = document.getElementById("ranking-modal-tbody");

    if (!modal || !backdrop || !content || !tbody) return;

    let titleText = "Ranking";
    let sortKeyAtual = "";
    let sortKeyTrim = "";
    let sortKeyAno = "";
    let isCurr = false;

    if (metric === "dev") {
      titleText = "Ranking de Devoluções";
      sortKeyAtual = "dev_atual";
      sortKeyTrim = "dev_trim";
      sortKeyAno = "dev_ant";
      isCurr = true;
    } else if (metric === "bon") {
      titleText = "Ranking de Bonificações";
      sortKeyAtual = "bon_atual";
      sortKeyTrim = "bon_trim";
      sortKeyAno = "bon_ant";
      isCurr = true;
    }

    title.textContent = titleText;

    // Filter out rows with 0 or null values for the current metric to make it cleaner, or just sort them
    let data = [...globalVendedoresData];

    // Sort descending
    data.sort((a, b) => (b[sortKeyAtual] || 0) - (a[sortKeyAtual] || 0));

    // Render table
    tbody.innerHTML = data.map((v, idx) => {
        const valAtual = v[sortKeyAtual] || 0;
        const valTrim = v[sortKeyTrim] || 0;
        const valAno = v[sortKeyAno] || 0;

        if (valAtual === 0 && valTrim === 0 && valAno === 0) return ''; // Skip empty rows

        const fmt = isCurr ? formatCurrency : formatNumber;

        let medal = `<span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-white/10 text-xs font-bold text-slate-300">${idx + 1}</span>`;
        if (idx === 0) medal = `🥇`;
        if (idx === 1) medal = `🥈`;
        if (idx === 2) medal = `🥉`;

        return `
            <tr class="hover:bg-white/5 transition-colors">
                <td class="px-4 py-3 text-center">${medal}</td>
                <td class="px-4 py-3 font-medium text-white">
                    <div class="truncate max-w-[150px]" title="${v.vendedor}">${v.vendedor}</div>
                    <div class="text-[10px] text-slate-500">${v.supervisor_nome || "N/A"}</div>
                </td>
                <td class="px-4 py-3 font-semibold text-fuchsia-400">${fmt(valAtual)}</td>
                <td class="px-4 py-3">${renderVarBadge(valAtual, valTrim)}</td>
                <td class="px-4 py-3">${renderVarBadge(valAtual, valAno)}</td>
            </tr>
        `;
    }).join("");

    // Show modal
    modal.classList.remove("hidden");
    modal.classList.add("flex");

    // Trigger animation
    requestAnimationFrame(() => {
      backdrop.classList.remove("opacity-0");
      content.classList.remove("scale-95", "opacity-0");
      content.classList.add("scale-100", "opacity-100");
    });
  }

  window.closeRankingModal = closeRankingModal;
  function closeRankingModal() {
    const modal = document.getElementById("ranking-modal");
    const backdrop = document.getElementById("ranking-modal-backdrop");
    const content = document.getElementById("ranking-modal-content");

    if (!modal) return;

    backdrop.classList.add("opacity-0");
    content.classList.remove("scale-100", "opacity-100");
    content.classList.add("scale-95", "opacity-0");

    setTimeout(() => {
      modal.classList.add("hidden");
      modal.classList.remove("flex");
    }, 300);
  }
  function setupVendedores(vendedoresData) {
    if (!vendedoresData) return;

    const tabs = document.querySelectorAll("#top-vendedores-tabs button");
    const selectSup = document.getElementById(
      "top-vendedores-supervisor-filter",
    );
    const tbody = document.getElementById("presentation-vendedores-tbody");

    // Populate select
    const sups = [
      ...new Set(vendedoresData.map((v) => v.supervisor_nome).filter(Boolean)),
    ].sort();
    selectSup.innerHTML =
      '<option value="ALL">Todos</option>' +
      sups.map((s) => `<option value="${s}">${s}</option>`).join("");

    let currentTab = "fat_geral";
    let currentSup = "ALL";

    const thAtual = document.getElementById("th-atual");
    const thAnt = document.getElementById("th-ant");
    const thTrim = document.getElementById("th-trim");

    const renderTable = () => {
      if (currentTab.startsWith("fat_")) {
        if (thAtual) thAtual.textContent = "Fat. Atual";
        if (thAnt) thAnt.textContent = "Fat. Ano Ant.";
        if (thTrim) thTrim.textContent = "Fat. Trim Ant.";
      } else if (currentTab.startsWith("ton_")) {
        if (thAtual) thAtual.textContent = "Ton. Atual";
        if (thAnt) thAnt.textContent = "Ton. Ano Ant.";
        if (thTrim) thTrim.textContent = "Ton. Trim Ant.";
      } else if (currentTab.startsWith("pos_")) {
        if (thAtual) thAtual.textContent = "Pos. Atual";
        if (thAnt) thAnt.textContent = "Pos. Ano Ant.";
        if (thTrim) thTrim.textContent = "Pos. Trim Ant.";
      }

      let filtered = vendedoresData;
      if (currentSup !== "ALL")
        filtered = filtered.filter((v) => v.supervisor_nome === currentSup);

      // Sort based on tab
      let sortKey = "fat_atual";
      if (currentTab === "fat_salty") sortKey = "fat_atual_salty";
      if (currentTab === "fat_foods") sortKey = "fat_atual_foods";
      if (currentTab === "ton_salty") sortKey = "ton_atual_salty";
      if (currentTab === "ton_foods") sortKey = "ton_atual_foods";
      if (currentTab === "pos_salty") sortKey = "pos_atual_salty";
      if (currentTab === "pos_foods") sortKey = "pos_atual_foods";

      filtered.sort((a, b) => (b[sortKey] || 0) - (a[sortKey] || 0));
      const top10 = filtered.slice(0, 10);

      // Determine if formatting currency or number
      const isCurr = currentTab.startsWith("fat_");

      tbody.innerHTML = top10
        .map((v, idx) => {
          const valAtual = v[sortKey] || 0;
          let keyAntYear = sortKey.replace("_atual", "_ant");
          let keyAntTrim = sortKey.replace("_atual", "_trim");
          if (sortKey === "fat_atual") {
            keyAntYear = "fat_ant";
            keyAntTrim = "fat_trim";
          }

          const valYear = v[keyAntYear] || 0;
          const valTrim = v[keyAntTrim] || 0;

          const fmt = isCurr ? formatCurrency : formatNumber;

          let medal = `<span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-white/10 text-xs font-bold text-slate-300">${idx + 1}</span>`;
          if (idx === 0) medal = `🥇`;
          if (idx === 1) medal = `🥈`;
          if (idx === 2) medal = `🥉`;

          return `
                    <tr class="hover:bg-white/5 transition-colors">
                        <td class="px-4 py-3 text-center">${medal}</td>
                        <td class="px-4 py-3 font-medium text-white">
                            <div class="truncate max-w-[150px]" title="${v.vendedor}">${v.vendedor}</div>
                            <div class="text-[10px] text-slate-500">${v.supervisor_nome || "N/A"}</div>
                        </td>
                        <td class="px-4 py-3 font-semibold text-fuchsia-400">${fmt(valAtual)}</td>
                        <td class="px-4 py-3 text-slate-400">${fmt(valYear)}</td>
                        <td class="px-4 py-3 text-slate-400">${fmt(valTrim)}</td>
                        <td class="px-4 py-3">${renderVarBadge(valAtual, valYear)}</td>
                        <td class="px-4 py-3">${renderVarBadge(valAtual, valTrim)}</td>
                    </tr>
                `;
        })
        .join("");

      if (top10.length === 0)
        tbody.innerHTML = `<tr><td colspan="7" class="px-4 py-4 text-center text-slate-500">Nenhum vendedor encontrado.</td></tr>`;
    };

    const profileIcon = document.getElementById("top-vendedores-profile-icon");
    const profileFallback = document.getElementById("top-vendedores-profile-fallback");

    function updateProfileIcon(supName) {
      if (!profileIcon || !profileFallback) return;

      profileIcon.classList.remove("hidden");
      profileFallback.classList.add("hidden");

      if (supName === "ALL") {
        profileIcon.src = "src/assets/images/PRIME.png";
      } else if (supName && supName.includes("AMERICANAS")) {
        profileIcon.src = "src/assets/images/AMERICANAS.png";
      } else if (supName && supName.includes("TIAGO")) {
        profileIcon.src = "src/assets/images/SHARK.png";
      } else if (supName && (supName.includes("RÔMULO") || supName.includes("ROMULO"))) {
        profileIcon.src = "src/assets/images/AGUIA.png";
      } else {
        profileIcon.classList.add("hidden");
        profileFallback.classList.remove("hidden");
      }
    }

    selectSup.addEventListener("change", (e) => {
      currentSup = e.target.value;
      updateProfileIcon(currentSup);
      renderTable();
    });

    // Initialize with default
    updateProfileIcon(currentSup);

    tabs.forEach((btn) => {
      btn.addEventListener("click", () => {
        tabs.forEach((b) => {
          b.classList.remove(
            "bg-[#fc0100]/20",
            "text-[#fc0100]",
            "border-[#fc0100]/50",
          );
          b.classList.add("bg-white/5", "text-slate-400", "border-transparent");
        });
        btn.classList.add(
          "bg-[#fc0100]/20",
          "text-[#fc0100]",
          "border-[#fc0100]/50",
        );
        btn.classList.remove("bg-white/5", "text-slate-400");
        currentTab = btn.getAttribute("data-tab");
        renderTable();
      });
    });

    renderTable();
  }

  // --- UTILS ---
  function formatCurrency(val) {
    if (val === undefined || val === null) return "R$ 0,00";
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
    }).format(val);
  }

  function formatPercent(val) {
    if (val === undefined || val === null) return "0%";
    return new Intl.NumberFormat("pt-BR", {
      style: "percent",
      maximumFractionDigits: 1,
    }).format(val / 100);
  }

  function formatNumber(val) {
    if (val === undefined || val === null) return "0";
    return new Intl.NumberFormat("pt-BR", {
      maximumFractionDigits: 0,
    }).format(val);
  }

  function renderVarBadge(atual, anterior) {
    if (!anterior || anterior === 0) {
      return atual > 0
        ? `<span class="text-emerald-400 font-medium">↑ +100%</span>`
        : `<span class="text-slate-500">-</span>`;
    }
    const varPct = ((atual - anterior) / Math.abs(anterior)) * 100;
    const fmt = formatPercent(Math.abs(varPct));
    if (varPct > 0)
      return `<span class="text-emerald-400 font-medium">↑ ${fmt}</span>`;
    if (varPct < 0)
      return `<span class="text-red-400 font-medium">↓ ${fmt}</span>`;
    return `<span class="text-slate-400 font-medium">0%</span>`;
  }

  // --- AI LOGIC ---
  async function generateAiAnalysis(apiKey, modelName, data) {
    // Prepare comprehensive data context for the LLM
    const global = data.global?.[0] || {};
    const varFatAno = global.fat_ant
      ? (((global.fat_atual - global.fat_ant) / global.fat_ant) * 100).toFixed(
          1,
        )
      : 0;

    const topFiliais = (data.filiais || [])
      .slice(0, 3)
      .map(
        (f) =>
          `${f.nome}: ${formatCurrency(f.fat_atual)} (Var: ${f.fat_ant ? (((f.fat_atual - f.fat_ant) / f.fat_ant) * 100).toFixed(1) : 0}%)`,
      )
      .join(", ");
    const topSupervisores = (data.supervisores || [])
      .slice(0, 3)
      .map((s) => `${s.nome}: ${formatCurrency(s.fat_atual)}`)
      .join(", ");
    const topRedes = (data.redes || [])
      .slice(0, 3)
      .map((r) => `${r.nome}: ${formatCurrency(r.fat_atual)}`)
      .join(", ");
    const topVendedores = (data.top_vendedores || [])
      .slice(0, 3)
      .map((v) => `${v.nome}: ${formatCurrency(v.fat_atual)}`)
      .join(", ");

    let promptText = `Crie um roteiro falado (script de apresentação) para que eu possa apresentar os resultados comerciais de fechamento.
Abaixo estão os dados completos do fechamento comercial:

### Visão Geral:
- Faturamento Atual: ${formatCurrency(global.fat_atual || 0)} (Variação vs Ano Anterior: ${varFatAno}%)
- Volume Kg Atual: ${formatNumber(global.ton_atual || 0)} Kg (Variação vs Mês Anterior: ${global.ton_trim ? (((global.ton_atual - global.ton_trim) / global.ton_trim) * 100).toFixed(1) : 0}%)
- Devoluções: ${formatCurrency(global.dev_atual || 0)} (Variação vs Ano Anterior: ${global.dev_ant ? (((global.dev_atual - global.dev_ant) / global.dev_ant) * 100).toFixed(1) : 0}%)
- Bonificações: ${formatCurrency(global.bonificacao_atual || 0)} (Variação vs Ano Anterior: ${global.bonificacao_ant ? (((global.bonificacao_atual - global.bonificacao_ant) / global.bonificacao_ant) * 100).toFixed(1) : 0}%)
- Positivação (Clientes Ativos): ${formatNumber(global.pos_atual || 0)} (Variação vs Mês Anterior: ${global.pos_ant_trim ? (((global.pos_atual - global.pos_ant_trim) / global.pos_ant_trim) * 100).toFixed(1) : 0}%)

### Destaques por Segmento (Top 3):
- Top Filiais: ${topFiliais || "N/A"}
- Top Supervisores: ${topSupervisores || "N/A"}
- Top Atacados/Redes: ${topRedes || "N/A"}
- Top Vendedores: ${topVendedores || "N/A"}

Aja estritamente como um roteirista. Seu objetivo é apenas apresentar esses números de forma fluida, como se fosse o teleprompter de um apresentador. Dê alguns toques de fala em cima de cada ponto para conectar os assuntos.
REGRAS IMPORTANTES:
1. NÃO invente motivos, justificativas ou sugestões de negócios para os números.
2. NÃO crie planos de ação ou "Recomendações Práticas".
3. O foco é apenas narrar os números de forma executiva e clara.`;

    try {
      const response = await fetch(
        "https://api.deepseek.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model: modelName,
            messages: [
              {
                role: "system",
                content:
                  "Você é um roteirista que cria discursos executivos focados apenas em apresentar os resultados numéricos, sem sugerir ações de negócios.",
              },
              { role: "user", content: promptText },
            ],
            temperature: 0.5,
            max_tokens: 1500,
          }),
        },
      );
      if (!response.ok) throw new Error("Erro na API da IA");
      const resData = await response.json();
      return resData.choices[0].message.content;
    } catch (e) {
      console.error(e);
      return "Erro ao comunicar com a inteligência artificial.";
    }
  }

  // --- DOCX DOWNLOAD ---
  btnDownload.addEventListener("click", async () => {
    if (!window.docx || !aiAnalysisText) return;
    try {
      const { Document, Packer, Paragraph, TextRun } = window.docx;

      const paragraphs = aiAnalysisText
        .split("\n")
        .filter((p) => p.trim() !== "")
        .map((text) => {
          return new Paragraph({
            children: [new TextRun({ text: text, size: 24 })],
            spacing: { after: 200 },
          });
        });

      const doc = new Document({
        sections: [
          {
            properties: {},
            children: [
              new Paragraph({
                children: [
                  new TextRun({
                    text: "Resumo Executivo - Fechamento Comercial",
                    bold: true,
                    size: 32,
                  }),
                ],
                spacing: { after: 400 },
              }),
              ...paragraphs,
            ],
          },
        ],
      });

      const blob = await Packer.toBlob(doc);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "Analise_Fechamento.docx";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error(e);
      alert("Erro ao gerar arquivo Word.");
    }
  });

  // START
  loadData();
});
