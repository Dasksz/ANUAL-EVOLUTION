import supabase from './supabase.js?v=5';
const $ = id => document.getElementById(id);
let state, editing, recovery, busy = false, loadEpoch = 0;
const labels = {aprovar:'Autorização aprovada',negar:'Autorização negada',revogar:'WhatsApp revogado',administrador:'WhatsApp administrativo alterado',editar:'Cadastro atualizado',cadastrar:'Colaborador cadastrado',preservar_rh:'Proteção da sincronização atualizada',envio_diario:'Envio diário atualizado'};
function node(tag, text, cls) {const el=document.createElement(tag); if(text!=null)el.textContent=text; if(cls)el.className=cls; return el;}
function button(text, action, id, values) {const el=node('button',text);el.onclick=()=>act(action,id,values);return el;}
async function rpc(name,args) {const {data,error}=await supabase.rpc(name,args);if(error)throw new Error(error.message);return data;}
async function load() {
  const epoch = ++loadEpoch;
  recovery = null;
  renderRecovery();
  try {
    const access=await rpc('elma_management_access');
    if(epoch!==loadEpoch)return;
    if(!access?.allowed)throw new Error('Acesso exclusivo do administrador master. Entre no dashboard com a conta autorizada.');
    const data=await rpc('elma_management_data');
    if(epoch!==loadEpoch)return;
    state=data;$('access').textContent='Administrador master';$('panel').classList.remove('hidden');render();
    await loadRecovery(epoch);
  }catch(e){if(epoch===loadEpoch){state=null;recovery=null;$('panel').classList.add('hidden');$('access').textContent=e.message;renderRecovery();}}
}
function render() {
  $('requests').replaceChildren();
  for(const r of state.pendentes){const row=node('div',null,'row'),info=node('div');info.append(node('strong',`A${r.id} • ${r.nome}`),node('p',`${r.funcao||'Função pendente'} • CPF final ${r.cpf_final||'—'} • +${r.phone}`));if(r.proposed_rca)info.append(node('p',`RCA informado: ${r.proposed_rca} • Código atual: ${displayCode(r.codigo)}`));const actions=node('div',null,'actions');if(r.cadastrado){if(r.acesso_efetivo==='Promotor'){const label=node('label','Código de promotor para aprovação'),input=node('input');input.value=r.proposed_promoter_code||r.promotor_codigo||'';input.placeholder='Ex.: promotor3007';input.maxLength=64;label.append(input);info.append(label);const approve=node('button','Aprovar');approve.onclick=()=>act('aprovar',r.id,{promotor_codigo:input.value.trim()});actions.append(approve);}else actions.append(button('Aprovar','aprovar',r.id));}else info.append(node('p',`Cadastro necessário: use CADASTRAR A${r.id} no WhatsApp administrativo.`));actions.append(button('Negar','negar',r.id));row.append(info,actions);$('requests').append(row);}
  if(!state.pendentes.length)$('requests').append(node('p','Nenhuma autorização pendente.'));
  employees();$('events').replaceChildren();
  $('rh-status').textContent=state.rh_sync?.last_success ? `Sincronização horária ativa. Última atualização: ${new Date(state.rh_sync.last_success).toLocaleString('pt-BR')}. ${state.rh_sync.source_count} colaboradores no RH.` : 'Aguardando a primeira sincronização.';
  $('daily-switch').checked=state.envio_diario?.enabled===true;
  $('daily-status').textContent=state.envio_diario?.enabled ? 'Ativado: vendedores autorizados recebem às 7:30, em dias úteis.' : 'Desativado: nenhum envio automático aos vendedores.';
  for(const e of state.eventos)$('events').append(node('p',`${new Date(e.created_at).toLocaleString('pt-BR')} • ${labels[e.action]||e.action} • registro ${e.target}`));
  if(!state.eventos.length)$('events').append(node('p','Nenhuma alteração registrada pelo painel.'));
  renderRecovery();
}
function displayCode(code){return /^(RH_|COLAB_)/.test(code||'')?'Não atribuído':code||'—';}
function employees(){
  $('employees').replaceChildren();const term=$('search').value.toLocaleLowerCase('pt-BR');
  for(const c of state.colaboradores.filter(c=>`${c.nome} ${c.funcao} ${c.codigo} ${c.promotor_codigo||''}`.toLocaleLowerCase('pt-BR').includes(term))){const row=node('div',null,'row'),info=node('div');info.append(node('strong',c.nome),node('p',`${c.funcao||'Sem função'} • Código ${displayCode(c.codigo)} • CPF final ${c.cpf_final||'—'}`));
    const actions=node('div',null,'actions'),edit=node('button','Editar cadastro');edit.onclick=()=>{editing=c.id;$('edit-form').reset();$('edit-form').elements.cpf.closest('label').classList.add('hidden');$('edit-form').elements.cpf.required=false;for(const field of ['nome','funcao','codigo','perfil_acesso','promotor_codigo'])$('edit-form').elements[field].value=c[field]||'';$('edit-form').elements.preservar_rh.checked=c.preservar_rh;$('edit-title').textContent='Editar colaborador';$('edit').showModal();};actions.append(edit);
    const protect=node('label',null,'protect');const check=node('input');check.type='checkbox';check.checked=c.preservar_rh;check.onchange=()=>act('preservar_rh',c.id,{preservar_rh:check.checked});protect.append(check,document.createTextNode(' Preservar cadastro na sincronização do RH'));info.append(protect);
    info.append(node('p',`Permissão no atendimento: ${c.acesso_efetivo||c.perfil_acesso||'Colaborador'}`));
    if(c.acesso_efetivo==='Promotor')info.append(node('p',`Código de promotor: ${c.promotor_codigo||'Aguardando vínculo'}`));
    if(!c.vinculos.length)info.append(node('p','Sem WhatsApp autorizado.'));
    for(const a of c.vinculos){info.append(node('p',`+${a.phone}${a.admin?' • Administrador das autorizações':''}`));if(!a.admin)actions.append(button('Revogar WhatsApp','revogar',a.id),button('Usar para notificações administrativas','administrador',a.id));}
    row.append(info,actions);$('employees').append(row);
  }
}
async function act(action,id,values={}) {
  if(busy)return;
  const messages={aprovar:'Autorizar este WhatsApp para o colaborador indicado?',negar:'Negar esta solicitação?',revogar:'Revogar o acesso deste WhatsApp?',administrador:'Transferir as notificações e comandos administrativos para este WhatsApp autorizado?',editar:'Salvar as alterações deste colaborador?',cadastrar:'Cadastrar este colaborador?',preservar_rh:values.preservar_rh?'Preservar este cadastro mesmo se o CPF sair da planilha do RH?':'Permitir a exclusão deste cadastro se o CPF estiver ausente do RH?',envio_diario:values.enabled?'Ativar os envios automáticos das 7:30 aos vendedores autorizados?':'Desativar os envios automáticos?'};
  if(!confirm(messages[action])){render();return;}
  setBusy(true);
  try{await rpc('elma_management_action',{p_action:action,p_id:id,p_values:values});$('feedback').textContent=labels[action]+'.';$('edit').close();await load();}
  catch(e){$('feedback').textContent=e.message;if(state)render();}
  finally{setBusy(false);}
}

const recoveryReasons = {wrong_number:'Número incorreto',no_response:'Sem resposta após 48 horas',whatsapp_unavailable:'WhatsApp indisponível',ambiguous:'Validação ambígua',shared_phone:'Telefone compartilhado'};
const recoveryVerification = {pending:'Pendente',resolved:'Conferida',phone_confirmed:'Telefone confirmado',phone_corrected:'Telefone corrigido',not_found:'Cliente não localizado',closed:'Estabelecimento encerrado'};
function localDate(value, time = false) {
  if(!value)return '—';
  const text=String(value);
  if(!time && /^\d{4}-\d{2}-\d{2}$/.test(text))return text.split('-').reverse().join('/');
  const date=new Date(text);
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo',...(time?{dateStyle:'short',timeStyle:'short'}:{dateStyle:'short'})});
}
function safeCount(value) {return value!=null && value!=='' && Number.isFinite(Number(value)) && Number(value)>=0 ? Math.floor(Number(value)).toLocaleString('pt-BR') : '—';}
function setBusy(value) {
  busy=value;
  document.querySelectorAll('button').forEach(b=>b.disabled=busy);
  $('daily-switch').disabled=busy;
  recoveryControls();
}
function recoveryControls() {
  const ready=!!recovery && recovery.available!==false;
  $('recovery-switch').disabled=busy || !ready || recovery.can_manage!==true;
  for(const id of ['recovery-kind','recovery-team','recovery-reason','recovery-verification','recovery-export'])$(id).disabled=busy || !ready || recovery.can_export===false;
  $('recovery-scope').disabled=busy || !ready || recovery.can_export===false || $('recovery-kind').value==='all';
}
async function recoveryRpc(action, payload = {}) {
  let query=supabase.rpc('elma_recovery_management',{p_action:action,p_payload:payload});
  if(typeof query.abortSignal==='function' && typeof AbortSignal!=='undefined' && typeof AbortSignal.timeout==='function')query=query.abortSignal(AbortSignal.timeout(30000));
  const {data,error}=await query;
  if(error)throw new Error(error.message);
  if(!data || data.error)throw new Error(data?.message || data?.error || 'Não foi possível consultar a recuperação de clientes.');
  return data;
}
async function loadRecovery(epoch = loadEpoch) {
  try {
    const data=await recoveryRpc('status');
    if(epoch!==loadEpoch)return;
    recovery=data;
    $('recovery-feedback').textContent='';
    renderRecovery();
    populateRecoveryFilters();
  } catch(e) {
    if(epoch!==loadEpoch)return;
    recovery=null;
    renderRecovery();
    $('recovery-state').textContent='Indisponível';
    $('recovery-status').textContent='Não foi possível confirmar a configuração. Os controles estão bloqueados até a próxima consulta.';
    $('recovery-feedback').textContent=e.message;
  }
}
function renderRecovery() {
  const enabled=recovery?.enabled===true;
  $('recovery-switch').checked=enabled;
  $('recovery-state').textContent=recovery ? enabled?'Ligado':'Desligado' : 'Consultando…';
  $('recovery-state').classList.toggle('enabled',enabled);
  $('recovery-status').textContent=recovery ? enabled ? `Ligado: novos contatos liberados.${recovery.next_start?` Próximo envio: ${localDate(recovery.next_start,true)}.`:''}` : 'Desligado: nenhum novo contato será iniciado. As conversas abertas continuam sendo recebidas.' : 'Consultando a configuração…';
  if(recovery && recovery.can_manage!==true)$('recovery-status').textContent+=' Somente o administrador master pode alterar este controle.';
  $('recovery-today').textContent=safeCount(recovery?.today_count);
  $('recovery-active').textContent=safeCount(recovery?.stats?.active_conversations);
  $('recovery-field').textContent=safeCount(recovery?.stats?.pending_verifications);
  recoveryControls();
}
function filterValue(item) {return String(typeof item==='string'?item:item.code ?? item.id ?? item.name ?? '');}
function filterLabel(item) {return String(typeof item==='string'?item:item.name ?? item.code ?? item.id ?? '');}
function replaceOptions(id, firstLabel, firstValue, values, previous) {
  const select=$(id),seen=new Set([firstValue]);
  select.replaceChildren();
  const first=node('option',firstLabel);first.value=firstValue;select.append(first);
  for(const item of values) {
    const value=filterValue(item);
    if(!value || seen.has(value))continue;
    seen.add(value);
    const option=node('option',filterLabel(item));option.value=value;select.append(option);
  }
  select.value=seen.has(previous)?previous:firstValue;
}
function populateRecoveryFilters() {
  const kind=$('recovery-kind').value,team=$('recovery-team').value,scope=$('recovery-scope').value;
  const teams=(recovery?.filters?.teams || []).filter(t=>!t.kind || kind==='all' || t.kind===kind);
  replaceOptions('recovery-team','Todas as equipes','',teams,team);
  const list=kind==='seller'?recovery?.filters?.sellers || []:kind==='promoter'?recovery?.filters?.promoters || []:[];
  const selectedTeam=$('recovery-team').value;
  const owners=list.filter(item=>!selectedTeam || String(item.team ?? '')===selectedTeam).map(item=>({code:item.code,name:`${item.name || item.code} — ${item.code}`}));
  replaceOptions('recovery-scope',kind==='promoter'?'Todos os promotores':kind==='seller'?'Todos os vendedores':'Todos os responsáveis','*',owners,scope);
  recoveryControls();
}
async function toggleRecovery(enabled) {
  if(busy || recovery?.can_manage!==true){renderRecovery();return;}
  if(!confirm(enabled?'Ativar os novos contatos de recuperação? Até 15 clientes serão contatados por dia, a partir das 9h30, a cada 5 minutos. Ative quando o comercial estiver disponível.':'Suspender novos contatos de recuperação? As conversas abertas continuarão sendo recebidas.')){renderRecovery();return;}
  const epoch=loadEpoch;
  setBusy(true);
  $('recovery-feedback').textContent='Salvando a configuração…';
  try {
    await recoveryRpc('toggle',{enabled});
    if(epoch!==loadEpoch)return;
    await loadRecovery(epoch);
    if(epoch===loadEpoch && recovery)$('recovery-feedback').textContent=enabled?'Novos contatos ativados.':'Novos contatos suspensos. As respostas das conversas abertas continuam sendo recebidas.';
  }catch(e){if(epoch===loadEpoch){recovery=null;renderRecovery();$('recovery-state').textContent='Não confirmado';$('recovery-status').textContent='Não foi possível confirmar a configuração. Atualize as informações antes de tentar novamente.';$('recovery-feedback').textContent=`Não foi possível confirmar a alteração: ${e.message}`;}}
  finally{setBusy(false);}
}
function recoveryExportPayload() {
  const kind=$('recovery-kind').value;
  return {kind,scope:kind==='all'?'*':$('recovery-scope').value,team:$('recovery-team').value || null,status:$('recovery-reason').value,verification:$('recovery-verification').value};
}
function recoveryWorkbook(rows, payload, library) {
  const columns=[['Código do cliente','codigo_cliente'],['Nome fantasia','nome_fantasia'],['CNPJ','cnpj'],['Cidade','cidade'],['Bairro','bairro'],['Endereço','endereco'],['Telefone cadastrado','telefone_cadastrado'],['Telefone original da base','telefone_origem'],['Telefone confirmado em campo','telefone_confirmado'],['Telefone testado','telefone_testado'],['Vendedor','vendedor'],['Promotor','promotor'],['Última compra','ultima_compra'],['Tentativa de contato','tentativa_em'],['Motivo da verificação','motivo'],['Situação da verificação','situacao_verificacao'],['Verificado por','verificado_por'],['Verificado em','verificado_em']];
  const matrix=[columns.map(c=>c[0]),...rows.map(row=>columns.map(([,key])=>{
    const value=row[key];
    if(key==='ultima_compra')return localDate(value);
    if(key==='tentativa_em' || key==='verificado_em')return localDate(value,true);
    if(key==='motivo')return recoveryReasons[value] || String(value ?? '');
    if(key==='situacao_verificacao')return recoveryVerification[value] || String(value ?? '');
    return String(value ?? '');
  }))];
  const sheet=library.utils.aoa_to_sheet(matrix);
  sheet['!cols']=columns.map(([,key])=>({wch:['nome_fantasia','endereco','vendedor','promotor'].includes(key)?34:['motivo','situacao_verificacao'].includes(key)?28:20}));
  sheet['!autofilter']={ref:sheet['!ref']};
  const workbook=library.utils.book_new();library.utils.book_append_sheet(workbook,sheet,'Verificação em campo');
  const owner=$('recovery-scope').selectedOptions[0]?.textContent || 'Todos os responsáveis';
  const team=$('recovery-team').selectedOptions[0]?.textContent || 'Todas as equipes';
  const info=[['Verificação de contatos — Prime Distribuição'],['Gerado em',localDate(new Date().toISOString(),true)],['Carteira',payload.kind==='seller'?'Vendedores':payload.kind==='promoter'?'Promotores':'Todas as carteiras'],['Responsável',owner],['Equipe',team],['Motivo',recoveryReasons[payload.status] || 'Todos os motivos'],['Situação',recoveryVerification[payload.verification] || 'Todas as situações'],['Clientes no arquivo',String(rows.length)],[],['Como atualizar','O vendedor ou promotor usa “Atualizar WhatsApp de um cliente” no atendimento Elma.'],['Sem resposta','48 horas sem retorno não tornam o número inválido.'],['Contato incorreto','Não repetir a abordagem ao número informado como incorreto.']];
  const guide=library.utils.aoa_to_sheet(info);guide['!cols']=[{wch:28},{wch:100}];library.utils.book_append_sheet(workbook,guide,'Orientações');
  return workbook;
}
async function exportRecovery(e) {
  e.preventDefault();
  if(busy || !recovery || recovery.can_export===false)return;
  const epoch=loadEpoch,payload=recoveryExportPayload();
  setBusy(true);$('recovery-export-status').textContent='Preparando a planilha…';
  try {
    const data=await recoveryRpc('export',payload);
    if(epoch!==loadEpoch)return;
    if(!Array.isArray(data.rows))throw new Error('A lista retornada não pôde ser conferida.');
    if(!data.rows.length){$('recovery-export-status').textContent='Nenhum cliente encontrado para esses filtros. Nenhum arquivo foi gerado.';return;}
    if(data.truncated===true)throw new Error('A lista excedeu o limite de exportação. Selecione uma equipe ou um responsável para gerar a lista completa.');
    if(!window.XLSX?.utils)throw new Error('O gerador de planilhas não carregou. Atualize a página e tente novamente.');
    const book=recoveryWorkbook(data.rows,payload,window.XLSX);
    const stamp=new Date().toLocaleDateString('en-CA',{timeZone:'America/Sao_Paulo'});
    window.XLSX.writeFile(book,`verificacao-contatos-${payload.kind}-${stamp}.xlsx`,{bookType:'xlsx'});
    $('recovery-export-status').textContent=`Planilha gerada com ${safeCount(data.rows.length)} ${data.rows.length===1?'cliente':'clientes'}.`;
  }catch(err){if(epoch===loadEpoch)$('recovery-export-status').textContent=`Não foi possível gerar a planilha: ${err.message}`;}
  finally{setBusy(false);}
}
$('search').oninput=employees;$('refresh').onclick=load;$('cancel').onclick=()=>$('edit').close();
$('edit-form').onsubmit=e=>{e.preventDefault();const values=Object.fromEntries(new FormData(e.currentTarget));values.preservar_rh=e.currentTarget.elements.preservar_rh.checked;act(editing?'editar':'cadastrar',editing||0,values);};
$('new-employee').onclick=()=>{editing=null;$('edit-form').reset();$('edit-form').elements.cpf.closest('label').classList.remove('hidden');$('edit-form').elements.cpf.required=true;$('edit-form').elements.perfil_acesso.value='Colaborador';$('edit-title').textContent='Cadastrar colaborador';$('edit').showModal();};
$('daily-switch').onchange=e=>act('envio_diario',0,{enabled:e.target.checked});
$('recovery-switch').onchange=e=>toggleRecovery(e.target.checked);
$('recovery-kind').onchange=()=>{$('recovery-team').value='';$('recovery-scope').value='*';populateRecoveryFilters();$('recovery-export-status').textContent='';};
$('recovery-team').onchange=()=>{$('recovery-scope').value='*';populateRecoveryFilters();$('recovery-export-status').textContent='';};
$('recovery-export-form').onsubmit=exportRecovery;
supabase.auth.onAuthStateChange(()=>{loadEpoch++;state=null;recovery=null;$('panel').classList.add('hidden');renderRecovery();setTimeout(load,0);});load();

