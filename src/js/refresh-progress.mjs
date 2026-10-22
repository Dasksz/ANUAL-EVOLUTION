export function refreshProgressModel(run) {
    if (!run) return { visible: false };
    const total = Math.max(0, Number(run.total) || 0);
    const completed = Math.min(total, Math.max(0, Number(run.completed) || 0));
    const failed = Math.max(0, Number(run.failed) || 0);
    const done = run.status === 'succeeded' && completed === total && failed === 0;
    const active = ['queued', 'processing'].includes(run.status);
    return {
        visible: true, done, active,
        percent: done ? 100 : Math.min(99, total ? Math.floor(completed / total * 100) : 0),
        title: done ? 'Atualização concluída' : active ? 'Os painéis ainda estão sendo atualizados' : 'A atualização precisa de atenção',
        detail: done ? 'Atualize a página para visualizar os valores atualizados.' : active
            ? 'Os valores podem estar incompletos. Basta aguardar. Quando a atualização terminar, atualize a página para visualizar os valores atualizados.'
            : 'Há etapas que não foram concluídas. Os valores podem estar incompletos; a administração precisa verificar a atualização.',
        count: `${completed} de ${total} etapas concluídas${failed ? ` · ${failed} com falha` : ''}`
    };
}

let monitor;
export function startRefreshProgress(client, { invalidateCache = async () => {} } = {}) {
    if (monitor) return monitor;
    const root = document.getElementById('app-layout');
    if (!root) return;
    const banner = document.createElement('section');
    banner.id = 'dashboard-refresh-progress';
    banner.hidden = true;
    banner.setAttribute('role', 'status');
    banner.setAttribute('aria-live', 'polite');
    banner.style.cssText = 'position:sticky;top:0;z-index:35;margin:12px 16px;padding:14px 16px;border:1px solid #b7791f;border-radius:12px;background:#292112;color:#fff3cd;box-shadow:0 4px 14px #0004;';
    banner.innerHTML = '<div style="display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap"><strong data-title></strong><span data-count style="font-size:12px"></span></div><p data-detail style="margin:6px 0;font-size:13px;line-height:1.5"></p><div data-track role="progressbar" aria-label="Atualização dos painéis" aria-valuemin="0" aria-valuemax="100" style="height:8px;border-radius:8px;background:#ffffff25;overflow:hidden"><div data-fill style="height:100%;width:0;background:#fbbf24;transition:width .3s"></div></div><p data-check style="margin:6px 0 0;font-size:11px;opacity:.8"></p><button data-reload type="button" hidden style="margin-top:8px;padding:8px 14px;border:0;border-radius:8px;background:#e2fbe8;color:#14351e;font-weight:700;cursor:pointer">Atualizar página</button>';
    root.prepend(banner);
    const get = name => banner.querySelector(`[data-${name}]`);
    let timer, checking = false, lastRun, preparedRevision, preparing;
    let acknowledgedRevision;
    try { acknowledgedRevision = window.sessionStorage.getItem('dashboard_refresh_prepared'); } catch { /* storage may be disabled */ }
    const prepare = async run => {
        if (preparedRevision === run.revision) return;
        if (!preparing) preparing = (async () => {
            await invalidateCache();
            preparedRevision = run.revision;
            try { window.sessionStorage.setItem('dashboard_refresh_prepared', run.revision); } catch { /* optional */ }
        })().finally(() => { preparing = null; });
        await preparing;
    };
    get('reload').addEventListener('click', async () => {
        const button = get('reload');
        button.disabled = true;
        try {
            await prepare(lastRun);
            window.location.reload();
        } catch {
            get('check').textContent = 'Não foi possível preparar a atualização da página. Tente novamente.';
            button.disabled = false;
        }
    });
    async function check() {
        clearTimeout(timer);
        if (checking) return;
        checking = true;
        try {
            if (document.hidden || root.classList.contains('hidden')) return;
            const { data, error } = await client.rpc('get_dashboard_refresh_progress');
            if (error) throw error;
            const model = refreshProgressModel(data);
            banner.hidden = !model.visible || (model.done && data.revision === acknowledgedRevision);
            if (banner.hidden) return;
            lastRun = data;
            get('title').textContent = model.title;
            get('detail').textContent = model.detail;
            get('count').textContent = `${model.percent}% · ${model.count}`;
            get('track').setAttribute('aria-valuenow', String(model.percent));
            get('fill').style.width = `${model.percent}%`;
            get('fill').style.background = model.done ? '#4ade80' : '#fbbf24';
            get('reload').hidden = !model.done;
            get('check').textContent = 'Progresso verificado às ' + new Date().toLocaleTimeString('pt-BR') + '. Atualização automática a cada 30 segundos.';
            if (model.done) await prepare(data);
        } catch {
            // Never turn an unavailable status service into a false success or a fake percentage.
            if (!banner.hidden) get('check').textContent = 'Não foi possível verificar o progresso agora. Exibindo a última informação recebida; tentaremos novamente.';
        } finally {
            checking = false;
            timer = setTimeout(check, 30000);
        }
    }
    document.addEventListener('visibilitychange', () => { if (!document.hidden) void check(); });
    monitor = { check };
    void check();
    return monitor;
}
