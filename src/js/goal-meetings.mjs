import supabase from './supabase.js?v=5';
// Source: supplied workbook, Revisional tab. One entry per meeting date.
export let goalMeetings = [
  {
    "date": "2026-09-28",
    "participants": [
      {
        "name": "Rômulo",
        "area": "Comercial"
      },
      {
        "name": "Gomes",
        "area": "Comercial"
      },
      {
        "name": "Jeremias",
        "area": "Logística/Armazém"
      },
      {
        "name": "Lourivaldo",
        "area": "Logística/Armazém"
      },
      {
        "name": "Marcel",
        "area": "Comercial"
      },
      {
        "name": "Leonir",
        "area": "Comercial"
      },
      {
        "name": "Wander",
        "area": "Comercial"
      },
      {
        "name": "Osvaldo",
        "area": "Comercial"
      }
    ]
  },
  {
    "date": "2026-06-08",
    "participants": [
      {
        "name": "Rômulo",
        "area": "Comercial"
      },
      {
        "name": "Leonir",
        "area": "Comercial"
      },
      {
        "name": "Gomes",
        "area": "Comercial"
      },
      {
        "name": "Jeremias",
        "area": "Logística/Armazém"
      },
      {
        "name": "Osvaldo",
        "area": "Comercial"
      },
      {
        "name": "Lourivaldo",
        "area": "Logística/Armazém"
      },
      {
        "name": "Marcel",
        "area": "Comercial"
      },
      {
        "name": "Wander",
        "area": "Comercial"
      }
    ]
  }
];

function node(tag, className, text) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text) el.textContent = text;
  return el;
}
export function mountGoalMeetings(root = document) {
  const header = root.querySelector('#goals-view > header');
  if (!header || root.getElementById('goal-meetings-indicator')) return;
  const style = node('style');
  style.textContent = `
    .gm-indicator{flex:1;display:flex;flex-direction:column;align-items:center;gap:7px;min-width:0;max-height:106px;position:relative}
    .gm-label{font-size:11px;letter-spacing:.04em;color:#94a3b8;font-weight:600}
    .gm-dates{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));grid-auto-rows:36px;gap:8px;width:min(100%,280px);max-height:80px;overflow-y:auto;overflow-x:hidden;overscroll-behavior:contain;scrollbar-width:thin;scrollbar-color:#f9731660 transparent;padding:2px 4px;box-sizing:border-box;flex-shrink:0}\n    .gm-dates::-webkit-scrollbar{width:5px}\n    .gm-dates::-webkit-scrollbar-thumb{background:#f9731660;border-radius:6px}
    .gm-date{display:flex;align-items:center;justify-content:center;white-space:nowrap;min-width:0;gap:7px;border:1px solid #f9731645;background:#f9731610;color:#fdba74;border-radius:9px;padding:8px 12px;font-size:13px;font-weight:600;cursor:pointer}
    .gm-date:hover,.gm-date[aria-expanded="true"]{border-color:#fb923c;background:#f9731626}
    .gm-date:focus-visible,.gm-close:focus-visible{outline:2px solid #fb923c;outline-offset:3px}
    .gm-popover{position:fixed;z-index:1200;width:360px;max-width:calc(100vw - 24px);background:#19181f;border:1px solid #f9731650;border-radius:14px;box-shadow:0 18px 60px #0009;color:#e2e8f0;padding:16px}
    .gm-popover[hidden]{display:none}
    .gm-heading{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:12px}
    .gm-title{font-size:14px;font-weight:700;color:#fff}
    .gm-subtitle{font-size:12px;color:#94a3b8;margin-top:4px}
    .gm-close{background:transparent;border:0;color:#94a3b8;cursor:pointer;font-size:22px;line-height:1;padding:0 3px}
    .gm-list{list-style:none;padding:0;margin:0;max-height:min(350px,50vh);overflow:auto}
    .gm-person{display:flex;justify-content:space-between;align-items:center;gap:14px;padding:10px 0;border-top:1px solid #ffffff0d;font-size:13px}
    .gm-area{font-size:12px;color:#94a3b8;text-align:right}
    @media(max-width:767px){.gm-indicator{align-items:flex-start;flex:none;width:100%}.gm-popover{padding:14px}}
  `;
  root.head.append(style);
  const indicator = node('div','gm-indicator');
  indicator.id = 'goal-meetings-indicator';
  indicator.append(node('span','gm-label','Monitoramento de metas · reuniões'));
  const dates = node('div','gm-dates');
  indicator.append(dates);
  header.insertBefore(indicator,header.lastElementChild);
  const panel = node('div','gm-popover');
  panel.id = 'goal-meetings-popover';
  panel.hidden = true;
  panel.setAttribute('role','dialog');
  panel.setAttribute('aria-labelledby','goal-meetings-title');
  root.body.append(panel);
  let active = null;
  function close(restoreFocus = false) {
    panel.hidden = true;
    if (active) { active.setAttribute('aria-expanded','false'); if (restoreFocus) active.focus(); }
    active = null;
  }
  function position() {
    if (!active) return;
    const rect = active.getBoundingClientRect();
    const width = panel.offsetWidth;
    panel.style.left = Math.max(12,Math.min(window.innerWidth-width-12,rect.left+rect.width/2-width/2))+'px';
    const height = panel.offsetHeight;
    const below = rect.bottom+10;
    panel.style.top = Math.max(12,below+height<=window.innerHeight-12 ? below : rect.top-height-10)+'px';
  }
  function renderDates() {
  close();
  dates.replaceChildren();
  if (!goalMeetings.length) { const empty = node('span','gm-subtitle','Nenhuma reunião registrada'); empty.style.gridColumn = '1 / -1'; dates.append(empty); }
  for (const meeting of goalMeetings) {
    const label = meeting.date.split('-').reverse().join('/');
    const button = node('button','gm-date',label);
    button.type = 'button';
    button.setAttribute('aria-expanded','false');
    button.setAttribute('aria-controls',panel.id);
    button.setAttribute('aria-haspopup','dialog');
    button.setAttribute('aria-label','Ver participantes da reunião de '+label);
    dates.append(button);
    button.addEventListener('click',() => {
      if (active === button) { close(); return; }
      close();
      active = button;
      button.setAttribute('aria-expanded','true');
      panel.replaceChildren();
      const heading = node('div','gm-heading');
      const titles = node('div');
      const title = node('h2','gm-title','Reunião de '+label);
      title.id = 'goal-meetings-title';
      titles.append(title,node('p','gm-subtitle',meeting.participants.length+' participantes'));
      const dismiss = node('button','gm-close','×');
      dismiss.type = 'button';
      dismiss.setAttribute('aria-label','Fechar participantes');
      dismiss.addEventListener('click',()=>close(true));
      heading.append(titles,dismiss);
      const list = node('ul','gm-list');
      for (const person of meeting.participants) {
        const row = node('li','gm-person');
        row.append(node('span','',person.name),node('span','gm-area',person.area));
        list.append(row);
      }
      panel.append(heading,list);
      panel.hidden = false;
      position();
      dismiss.focus();
    });
  }
  }
  renderDates();
  root.addEventListener('pointerdown',event => {
    if (!panel.hidden && !panel.contains(event.target) && !indicator.contains(event.target)) close();
  });
  root.addEventListener('keydown',event => { if (event.key==='Escape' && active) close(true); });
  window.addEventListener('resize',position);
  window.addEventListener('scroll',event=> { if (!panel.contains(event.target)) close(); },true);
  // Changing dashboard views must not leave a floating panel behind.
  new MutationObserver(()=> { if (root.getElementById('goals-view').classList.contains('hidden')) close(); })
    .observe(root.getElementById('goals-view'),{attributes:true,attributeFilter:['class']});
  return { update(meetings, syncedAt) {
    if (JSON.stringify(goalMeetings) !== JSON.stringify(meetings)) { goalMeetings = meetings; renderDates(); }
    indicator.title = 'Sincronizado com Google Sheets em ' + new Date(syncedAt).toLocaleString('pt-BR');
  }, unavailable() { indicator.title = 'Não foi possível consultar a sincronização. Mostrando os últimos dados disponíveis.'; } };
}
if (typeof document !== 'undefined') {
  const controller = mountGoalMeetings();
  let loading = false;
  async function refreshMeetings() {
    if (!controller || loading || document.hidden) return;
    loading = true;
    try {
      const { data, error } = await supabase.from('goal_meetings_sync')
        .select('meetings,synced_at').eq('id', true).single();
      if (error || !data || !Array.isArray(data.meetings)) throw error || new Error('Invalid meetings response');
      const meetings = data.meetings.map(meeting => {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(meeting.date) || !Array.isArray(meeting.participants)) throw new Error('Invalid meeting');
        return { date: meeting.date, participants: meeting.participants.map(person => {
          if (typeof person.name !== 'string' || typeof person.area !== 'string') throw new Error('Invalid participant');
          return { name: person.name, area: person.area };
        }) };
      }).sort((a, b) => b.date.localeCompare(a.date));
      controller.update(meetings, data.synced_at);
    } catch (error) {
      controller.unavailable();
      console.warn('Não foi possível atualizar as reuniões de metas', error);
    } finally { loading = false; }
  }
  refreshMeetings();
  supabase.auth.onAuthStateChange(() => { setTimeout(refreshMeetings, 0); });
  setInterval(refreshMeetings, 60000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refreshMeetings(); });
}
