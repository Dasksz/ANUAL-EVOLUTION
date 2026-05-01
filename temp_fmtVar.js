        // Trend Data Extraction
        const trendInfo = data.trend_info || { allowed: false, factor: 1, current_month_index: -1 };
        const applyTrend = boxesTrendActive && trendInfo.allowed;

        // Safe access helpers
        const safeVal = (v) => v || 0;
        const fmtBRL = (v) => formatCurrency(safeVal(v));
        const fmtKg = (v) => formatTons(safeVal(v), 1);
        const fmtCaixas = (v) => formatInteger(safeVal(v));

        const calcVar = (curr, prev) => {
            if (prev > 0) return ((curr / prev) - 1) * 100;
            return curr > 0 ? 100 : 0;
        };
        const fmtVar = (v) => {
            const cls = v >= 0 ? 'text-emerald-400' : 'text-red-400';
            const sign = v > 0 ? '+' : '';
            const span = document.createElement('span');
            span.className = cls;
            span.textContent = `${sign}${v.toFixed(1)}%`;
            return span;
        };

        // Determine View Mode (Year vs Month)
        // If boxesMesFilter is empty -> Year View (Accumulated)
        // If boxesMesFilter has value -> Month View (Specific Month)
        const isYearView = (boxesMesFilter.value === '');

        // --- KPI Logic Update for Trend ---
        const updateBoxKpi = (prefix, key, formatFn) => {
            let curr = safeVal(data.kpi_current[key]);
