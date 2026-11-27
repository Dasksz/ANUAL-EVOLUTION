const money = new Intl.NumberFormat('pt-BR', {style: 'currency', currency: 'BRL'});
const monthFormat = new Intl.DateTimeFormat('pt-BR', {month: 'long', year: 'numeric', timeZone: 'UTC'});
const dateFormat = new Intl.DateTimeFormat('pt-BR', {timeZone: 'UTC'});
const currency = cents => money.format(cents / 100);
const axisNumber = new Intl.NumberFormat('pt-BR', {maximumFractionDigits: 2});
const axisCurrency = cents => {
    const reais = cents / 100;
    if (Math.abs(reais) >= 1_000_000) return axisNumber.format(reais / 1_000_000) + 'M';
    if (Math.abs(reais) >= 1_000) return axisNumber.format(reais / 1_000) + 'K';
    return axisNumber.format(reais);
};
const normalized = value => value.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase('pt-BR').trim();
const dateOf = value => new Date(value + 'T00:00:00Z');
const monthLabel = value => monthFormat.format(dateOf(value + '-01'));
const total = rows => rows.reduce((sum, row) => sum + row.amount, 0);

const expenseIcons = {
    "calendar": "M5 6h14v14H5zM8 3v6m8-6v6M5 11h14",
    "person": "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2m12-14a4 4 0 1 1-8 0 4 4 0 0 1 8 0z",
    "team": "M3 20v-2a4 4 0 0 1 4-4h5a4 4 0 0 1 4 4v2m5 0v-2a4 4 0 0 0-3-4m-4-7a4 4 0 1 1-8 0 4 4 0 0 1 8 0zm3-4a4 4 0 0 1 0 8",
    "pin": "M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0zm-5 0a3 3 0 1 1-6 0 3 3 0 0 1 6 0z",
    "tag": "M3 4h8l10 10-7 7L3 10V4zm4 4h.01",
    "wallet": "M4 7h16v13H4zM4 7V4h13v3m3 5h-5v4h5",
    "bar": "M4 4v16h16M8 8h9M8 12h12M8 16h6",
    "pie": "M12 3v9h9M10 4a8 8 0 1 0 10 10"
};
const surface = 'bg-[#151419]/80 border border-white/10 rounded-xl shadow-lg';
const chartColors = {orange: '#f97316', comparison: '#64748b', extra: '#38bdf8', text: '#cbd5e1', grid: 'rgba(148, 163, 184, 0.18)'};

function panelIcon(name) {
    const badge = field('span', 'inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-orange-500/10 text-orange-400');
    badge.setAttribute('aria-hidden', 'true');
    badge.innerHTML = '<svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path stroke-width="2" stroke-linecap="round" stroke-linejoin="round" d="' + expenseIcons[name] + '"/></svg>';
    return badge;
}

export function previousExpenseMonth(month) {
    const date = dateOf(month + '-01');
    date.setUTCMonth(date.getUTCMonth() - 1);
    return date.toISOString().slice(0, 7);
}

export function expenseGroups(current, previous, key, missing) {
    const groups = new Map();
    [current, previous].forEach((rows, index) => {
        for (const row of rows) {
            const label = row[key] || missing;
            const id = normalized(label);
            if (!groups.has(id)) groups.set(id, {label, current: 0, previous: 0});
            groups.get(id)[index === 0 ? 'current' : 'previous'] += row.amount;
        }
    });
    return [...groups.values()].sort((a, b) => b.current - a.current || b.previous - a.previous || a.label.localeCompare(b.label, 'pt-BR'));
}

function field(tag, className, content) {
    const node = document.createElement(tag);
    node.className = className;
    if (content !== undefined) node.textContent = content;
    return node;
}

export function createExpensePanel({root, client}) {
    const month = root.querySelector('[data-expense-month]');
    const status = root.querySelector('[data-expense-status]');
    const refresh = root.querySelector('[data-expense-refresh]');
    const filters = root.querySelector('[data-expense-filters]');
    const results = root.querySelector('[data-expense-results]');
    const summary = root.querySelector('[data-expense-summary]');
    const chartsRoot = root.querySelector('[data-expense-charts]');
    const table = root.querySelector('tbody');
    const more = root.querySelector('[data-expense-more]');
    const selections = {supervisor: new Set(), coordenador: new Set(), city: new Set(), category: new Set()};
    let entries = [];
    let charts = [];
    let syncedAt = '';
    let request = 0;
    let limit = 100;

    function clearCharts() {
        charts.forEach(chart => chart.destroy());
        charts = [];
        chartsRoot.replaceChildren();
    }

    function renderOptions(key, options, label) {
        const host = filters.querySelector('[data-expense-filter="' + key + '"]');
        const selected = selections[key];
        const unique = new Map(options.map(option => [normalized(option), option]));
        for (const value of selected) if (!unique.has(value)) selected.delete(value);
        const heading = host.querySelector('[data-expense-filter-label]');
        heading.textContent = label + (selected.size ? ' (' + selected.size + ')' : '');
        const list = host.querySelector('div');
        list.replaceChildren();
        for (const [id, display] of [...unique].sort((a, b) => a[1].localeCompare(b[1], 'pt-BR'))) {
            const item = field('label', 'flex items-center gap-2 px-2 py-1.5 rounded-md cursor-pointer hover:bg-white/10');
            const input = document.createElement('input');
            input.type = 'checkbox';
            input.className = 'accent-orange-500';
            input.checked = selected.has(id);
            input.addEventListener('change', () => {
                if (input.checked) selected.add(id);
                else selected.delete(id);
                heading.textContent = label + (selected.size ? ' (' + selected.size + ')' : '');
                limit = 100;
                render();
            });
            item.append(input, document.createTextNode(display));
            list.append(item);
        }
        if (!unique.size) list.textContent = 'Sem opções no período.';
    }

    function selectedRows(period) {
        const hasPersonFilter = selections.supervisor.size || selections.coordenador.size;
        return entries.filter(row => {
            const group = normalized(row.role).startsWith('supervisor') ? 'supervisor' : 'coordenador';
            return row.date.startsWith(period) &&
                (!hasPersonFilter || selections[group].has(normalized(row.person))) &&
                (!selections.city.size || selections.city.has(normalized(row.city || 'Sem cidade'))) &&
                (!selections.category.size || selections.category.has(normalized(row.category || 'Sem categoria')));
        });
    }

    function chartCard(title, height, icon) {
        const card = field('article', surface + ' p-4 sm:p-5 min-w-0');
        const heading = field('h3', 'flex items-center gap-2 font-bold text-white mb-4');
        heading.append(panelIcon(icon), document.createTextNode(title));
        card.append(heading);
        const viewport = field('div', 'overflow-auto max-h-[26rem]');
        const area = field('div', 'relative');
        area.style.height = height + 'px';
        const canvas = document.createElement('canvas');
        canvas.setAttribute('aria-label', title);
        canvas.setAttribute('role', 'img');
        area.append(canvas);
        viewport.append(area);
        card.append(viewport);
        chartsRoot.append(card);
        return {card, canvas, viewport};
    }

    function bar(title, data, period, previous) {
        const {canvas, viewport} = chartCard(title, Math.max(180, 58 + data.length * 34), 'bar');
        if (!data.length || !window.Chart) {
            viewport.replaceWith(field('p', 'text-slate-400 text-sm', data.length ? 'Gráfico indisponível.' : 'Sem gastos no recorte.'));
            return;
        }
        charts.push(new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: data.map(row => row.label),
                datasets: [
                    {label: monthLabel(period), data: data.map(row => row.current), backgroundColor: chartColors.orange, borderRadius: 3},
                    {label: monthLabel(previous), data: data.map(row => row.previous), backgroundColor: chartColors.comparison, borderRadius: 3},
                ],
            },
            options: {
                indexAxis: 'y', responsive: true, maintainAspectRatio: false,
                color: chartColors.text,
                font: {family: 'Inter, sans-serif'},
                plugins: {legend: {labels: {color: chartColors.text, usePointStyle: true}}, datalabels: {display: false}, tooltip: {callbacks: {label: item => item.dataset.label + ': ' + currency(item.parsed.x)}}},
                scales: {
                    x: {beginAtZero: true, grid: {color: chartColors.grid}, ticks: {color: chartColors.text, font: {size: 10}, maxTicksLimit: 9, callback: axisCurrency}},
                    y: {grid: {display: false}, ticks: {color: chartColors.text, font: {size: 10}, autoSkip: false}},
                },
            },
        }));
    }

    function pie(period, rows) {
        const {canvas, viewport} = chartCard('iFood × Extra · ' + monthLabel(period), 210, 'pie');
        const totals = ['ifood', 'extra'].map(type => total(rows.filter(row => normalized(row.type) === type)));
        if (!totals.some(value => value > 0) || !window.Chart) {
            viewport.replaceWith(field('p', 'text-slate-400 text-sm', window.Chart ? 'Sem gastos iFood ou Extra no recorte.' : 'Gráfico indisponível.'));
            return;
        }
        charts.push(new window.Chart(canvas, {
            type: 'pie',
            data: {labels: ['iFood', 'Extra'], datasets: [{data: totals, backgroundColor: [chartColors.orange, chartColors.extra], borderColor: '#151419', borderWidth: 2}]},
            options: {
                responsive: true, maintainAspectRatio: false,
                color: chartColors.text,
                font: {family: 'Inter, sans-serif'},
                plugins: {legend: {labels: {color: chartColors.text, usePointStyle: true}}, datalabels: {display: false}, tooltip: {callbacks: {label: item => item.label + ': ' + currency(item.raw)}}},
            },
        }));
    }

    function expenseCandles() {
        const periods = ['2026-09', '2026-10', '2026-11'];
        const {card, canvas, viewport} = chartCard('Evolução dos gastos · set–nov 2026', 210, 'bar');
        const totals = periods.map(period => {
            const rows = selectedRows(period);
            return rows.length ? total(rows) : null;
        });
        const caption = field('p', 'mt-3 text-xs text-slate-400',
            'A altura de cada vela mostra o total gasto no mês.');
        card.append(caption);
        if (totals.every(value => value === null) || !window.Chart) {
            viewport.replaceWith(field('p', 'text-slate-400 text-sm',
                window.Chart ? 'Sem gastos no recorte.' : 'Gráfico indisponível.'));
            return;
        }

        charts.push(new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: ['Setembro', 'Outubro', 'Novembro'],
                datasets: [{
                    data: totals,
                    base: 0,
                    backgroundColor: chartColors.orange,
                    barThickness: 24,
                    minBarLength: 3,
                }],
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                font: {family: 'Inter, sans-serif'},
                plugins: {
                    legend: {display: false},
                    datalabels: {display: false},
                    tooltip: {callbacks: {label: item => {
                        const after = item.raw;
                        const before = totals[item.dataIndex - 1];
                        const lines = ['Total do mês: ' + currency(after)];
                        if (before != null) {
                            lines.push('Mês anterior: ' + currency(before), 'Variação: ' + currency(after - before));
                        }
                        return lines;
                    }}},
                },
                scales: {
                    x: {grid: {display: false}, ticks: {color: chartColors.text}},
                    y: {beginAtZero: true, grid: {color: chartColors.grid}, ticks: {color: chartColors.text, font: {size: 10}, maxTicksLimit: 9, callback: axisCurrency}},
                },
            },
        }));
    }

    function tableRows(current) {
        table.replaceChildren();
        const rows = [...current].sort((a, b) => b.date.localeCompare(a.date));
        for (const item of rows.slice(0, limit)) {
            const row = field('tr', item.reimbursed ? 'border-t border-white/10 text-slate-400 bg-white/[0.02]' : 'border-t border-white/10 hover:bg-white/5');
            const values = [dateFormat.format(dateOf(item.date)), item.person, item.category, item.description, item.city];
            for (const value of values) row.append(field('td', 'px-3 py-2', value || '—'));
            const amount = field('td', 'px-3 py-2 whitespace-nowrap text-right tabular-nums');
            if (item.reimbursed) amount.append(field('strong', 'font-bold', 'REEMBOLSADO'));
            else amount.textContent = currency(item.amount);
            row.append(amount);
            table.append(row);
        }
        if (!rows.length) {
            const row = document.createElement('tr');
            const cell = field('td', 'py-6 text-center text-slate-400', 'Nenhum lançamento para os filtros selecionados.');
            cell.colSpan = 6;
            row.append(cell);
            table.append(row);
        }
        more.hidden = rows.length <= limit;
    }

    function render() {
        const period = month.value;
        if (!period) return;
        const previous = previousExpenseMonth(period);
        const current = selectedRows(period);
        const prior = selectedRows(previous);
        const people = expenseGroups(current, prior, 'person', 'Sem pessoa');
        const cities = expenseGroups(current, prior, 'city', 'Sem cidade');
        const categories = expenseGroups(current, prior, 'category', 'Sem categoria');
        const leading = (items, missing) => {
            const item = items.find(group => group.current !== 0 && group.label !== missing);
            return item ? item.label + ' · ' + currency(item.current) : '—';
        };
        const comparison = total(prior) ? new Intl.NumberFormat('pt-BR', {style: 'percent', maximumFractionDigits: 1, signDisplay: 'exceptZero'}).format(total(current) / total(prior) - 1) : '—';
        const cards = [
            ['wallet', 'Gasto no mês', currency(total(current)), comparison + ' vs. ' + monthLabel(previous)],
            ['calendar', 'Gasto no mês anterior', currency(total(prior)), monthLabel(previous)],
            ['person', 'Pessoa com maior gasto', leading(people)],
            ['team', 'Setor com maior gasto', leading(expenseGroups(current.map(row => ({...row, sector: normalized(row.role).includes('merchandising') ? 'Merchandising' : 'Comercial'})), [], 'sector', 'Sem setor'))],
            ['pin', 'Cidade com maior gasto', leading(cities, 'Sem cidade')],
            ['tag', 'Categoria com maior gasto', leading(categories, 'Sem categoria')],
        ];
        summary.replaceChildren();
        for (const [icon, label, value, detail] of cards) {
            const card = field('div', surface + ' min-w-0 p-4');
            const heading = field('div', 'flex items-center gap-2');
            heading.append(panelIcon(icon), field('p', 'text-[11px] uppercase tracking-wider font-bold text-slate-300', label));
            const totalStyle = icon === 'wallet' ? ' text-orange-400 text-2xl' : ' text-white text-lg';
            card.append(heading, field('p', 'mt-3 break-words font-bold tabular-nums' + totalStyle, value));
            if (detail) card.append(field('p', 'text-xs mt-1 text-slate-400', detail));
            summary.append(card);
        }
        clearCharts();
        pie(period, current);
        expenseCandles();
        bar('Gastos por pessoa', people, period, previous);
        bar('Gastos por cidade', cities, period, previous);
        bar('Gastos por categoria', categories, period, previous);
        bar('Gastos por estabelecimento', expenseGroups(current, prior, 'merchant', 'Sem estabelecimento'), period, previous);
        tableRows(current);
    }

    function updatePeriod() {
        const periods = [month.value, previousExpenseMonth(month.value)];
        const visible = entries.filter(row => periods.includes(row.date.slice(0, 7)));
        renderOptions('supervisor', visible.filter(row => normalized(row.role).startsWith('supervisor')).map(row => row.person), 'Supervisores');
        renderOptions('coordenador', visible.filter(row => normalized(row.role).startsWith('coordenador')).map(row => row.person), 'Coordenadores');
        renderOptions('city', visible.map(row => row.city || 'Sem cidade'), 'Cidades');
        renderOptions('category', visible.map(row => row.category || 'Sem categoria'), 'Categorias');
        limit = 100;
        render();
    }

    async function activate() {
        const id = ++request;
        refresh.disabled = true;
        status.textContent = 'Carregando gastos…';
        try {
            const {data, error} = await client.from('evolution_expense_snapshot').select('entries,synced_at').eq('singleton', true).maybeSingle();
            if (id !== request) return;
            if (error) throw error;
            if (!data) {
                results.hidden = true;
                filters.hidden = true;
                status.textContent = 'Nenhuma carga de gastos disponível.';
                return;
            }
            entries = data.entries;
            syncedAt = new Date(data.synced_at).toLocaleString('pt-BR', {timeZone: 'America/Bahia'});
            const currentMonth = new Intl.DateTimeFormat('sv-SE', {year: 'numeric', month: '2-digit', timeZone: 'America/Bahia'}).format(new Date());
            const previousSelection = month.value || currentMonth;
            const periods = [...new Set([currentMonth, ...entries.map(row => row.date.slice(0, 7))])].sort().reverse();
            month.replaceChildren(...periods.map(period => new Option(monthLabel(period), period)));
            month.value = periods.includes(previousSelection) ? previousSelection : currentMonth;
            status.textContent = 'Última alteração sincronizada em ' + syncedAt;
            results.hidden = false;
            filters.hidden = false;
            updatePeriod();
        } catch (error) {
            if (id !== request) return;
            console.error('Erro ao carregar gastos', error);
            status.textContent = 'Não foi possível atualizar os gastos.' + (syncedAt ? ' Dados exibidos de ' + syncedAt + '.' : '');
        } finally {
            if (id === request) refresh.disabled = false;
        }
    }

    function deactivate() {
        request++;
        clearCharts();
        entries = [];
        syncedAt = '';
        results.hidden = true;
        filters.hidden = true;
        table.replaceChildren();
        summary.replaceChildren();
    }

    month.addEventListener('change', updatePeriod);
    refresh.addEventListener('click', activate);
    more.addEventListener('click', () => {
        limit += 100;
        tableRows(selectedRows(month.value));
    });
    root.querySelector('[data-expense-clear]').addEventListener('click', () => {
        Object.values(selections).forEach(selection => selection.clear());
        updatePeriod();
    });
    return {activate, deactivate};
}
