const money = new Intl.NumberFormat('pt-BR', {style: 'currency', currency: 'BRL'});
const monthFormat = new Intl.DateTimeFormat('pt-BR', {month: 'long', year: 'numeric', timeZone: 'UTC'});
const dateFormat = new Intl.DateTimeFormat('pt-BR', {timeZone: 'UTC'});
const currency = cents => money.format(cents / 100);
const normalized = value => value.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase('pt-BR').trim();
const dateOf = value => new Date(value + 'T00:00:00Z');
const monthLabel = value => monthFormat.format(dateOf(value + '-01'));
const total = rows => rows.reduce((sum, row) => sum + row.amount, 0);

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
    const selections = {supervisor: new Set(), coordenador: new Set(), city: new Set()};
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
        const heading = host.querySelector('summary');
        heading.textContent = label + (selected.size ? ' (' + selected.size + ')' : '');
        const list = host.querySelector('div');
        list.replaceChildren();
        for (const [id, display] of [...unique].sort((a, b) => a[1].localeCompare(b[1], 'pt-BR'))) {
            const item = field('label', 'flex items-center gap-2 p-1 cursor-pointer');
            const input = document.createElement('input');
            input.type = 'checkbox';
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
                (!selections.city.size || selections.city.has(normalized(row.city || 'Sem cidade')));
        });
    }

    function chartCard(title, height) {
        const card = field('article', 'bg-white rounded-xl border border-slate-200 p-4 min-w-0');
        card.append(field('h3', 'font-semibold text-slate-900 mb-3', title));
        const viewport = field('div', 'overflow-auto max-h-[36rem]');
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
        const {card, canvas, viewport} = chartCard(title, Math.max(210, 58 + data.length * 42));
        card.classList.add('lg:col-span-2');
        if (!data.length || !window.Chart) {
            viewport.replaceWith(field('p', 'text-slate-500 text-sm', data.length ? 'Gráfico indisponível.' : 'Sem gastos no recorte.'));
            return;
        }
        charts.push(new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: data.map(row => row.label),
                datasets: [
                    {label: monthLabel(period), data: data.map(row => row.current), backgroundColor: '#c2410c', borderRadius: 3},
                    {label: monthLabel(previous), data: data.map(row => row.previous), backgroundColor: '#64748b', borderRadius: 3},
                ],
            },
            options: {
                indexAxis: 'y', responsive: true, maintainAspectRatio: false,
                plugins: {datalabels: {display: false}, tooltip: {callbacks: {label: item => item.dataset.label + ': ' + currency(item.parsed.x)}}},
                scales: {x: {beginAtZero: true, ticks: {callback: currency}}, y: {ticks: {autoSkip: false}}},
            },
        }));
    }

    function pie(period, rows) {
        const {canvas, viewport} = chartCard('iFood × Extra · ' + monthLabel(period), 245);
        const totals = ['ifood', 'extra'].map(type => total(rows.filter(row => normalized(row.type) === type)));
        if (!totals.some(value => value > 0) || !window.Chart) {
            viewport.replaceWith(field('p', 'text-slate-500 text-sm', window.Chart ? 'Sem gastos iFood ou Extra no recorte.' : 'Gráfico indisponível.'));
            return;
        }
        charts.push(new window.Chart(canvas, {
            type: 'pie',
            data: {labels: ['iFood', 'Extra'], datasets: [{data: totals, backgroundColor: ['#c2410c', '#2563eb']}]},
            options: {
                responsive: true, maintainAspectRatio: false,
                plugins: {datalabels: {display: false}, tooltip: {callbacks: {label: item => item.label + ': ' + currency(item.raw)}}},
            },
        }));
    }

    function tableRows(current) {
        table.replaceChildren();
        const rows = [...current].sort((a, b) => b.date.localeCompare(a.date));
        for (const item of rows.slice(0, limit)) {
            const row = field('tr', item.reimbursed ? 'border-t border-slate-200 bg-slate-50 text-slate-500' : 'border-t border-slate-200');
            const values = [dateFormat.format(dateOf(item.date)), item.person, item.category, item.description, item.city];
            for (const value of values) row.append(field('td', 'px-3 py-2', value || '—'));
            const amount = field('td', 'px-3 py-2 whitespace-nowrap text-right');
            if (item.reimbursed) amount.append(field('strong', 'font-bold', 'REEMBOLSADO'));
            else amount.textContent = currency(item.amount);
            row.append(amount);
            table.append(row);
        }
        if (!rows.length) {
            const row = document.createElement('tr');
            const cell = field('td', 'py-6 text-center text-slate-500', 'Nenhum lançamento para os filtros selecionados.');
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
            ['Gasto no mês', currency(total(current)), comparison + ' vs. ' + monthLabel(previous)],
            ['Gasto no mês anterior', currency(total(prior)), monthLabel(previous)],
            ['Pessoa com maior gasto', leading(people)],
            ['Setor / função com maior gasto', leading(expenseGroups(current, prior, 'role', 'Sem função'))],
            ['Cidade com maior gasto', leading(cities, 'Sem cidade')],
            ['Estabelecimento com maior gasto', leading(expenseGroups(current, prior, 'merchant', 'Sem estabelecimento'), 'Sem estabelecimento')],
            ['Categoria com maior gasto', leading(categories, 'Sem categoria')],
        ];
        summary.replaceChildren();
        for (const [label, value, detail] of cards) {
            const card = field('div', 'bg-white border border-slate-200 rounded-xl p-4');
            card.append(field('p', 'text-xs font-semibold text-slate-600', label), field('p', 'mt-1 font-bold text-slate-900', value));
            if (detail) card.append(field('p', 'text-xs mt-1 text-slate-600', detail));
            summary.append(card);
        }
        clearCharts();
        pie(period, current);
        pie(previous, prior);
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
