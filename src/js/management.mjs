import supabase from './supabase.js?v=5';
const $ = id => document.getElementById(id);
let state, editing, busy = false;
const labels = {aprovar:'Autorização aprovada',negar:'Autorização negada',revogar:'WhatsApp revogado',administrador:'WhatsApp administrativo alterado',editar:'Cadastro atualizado',cadastrar:'Colaborador cadastrado',preservar_rh:'Proteção da sincronização atualizada',envio_diario:'Envio diário atualizado'};
function node(tag, text, cls) {const el=document.createElement(tag); if(text!=null)el.textContent=text; if(cls)el.className=cls; return el;}
function button(text, action, id, values) {const el=node('button',text);el.onclick=()=>act(action,id,values);return el;}
async function rpc(name,args) {const {data,error}=await supabase.rpc(name,args);if(error)throw new Error(error.message);return data;}
async function load() {
  try {
    const access=await rpc('elma_management_access');
    if(!access?.allowed)throw new Error('Acesso exclusivo do administrador master. Entre no dashboard com a conta autorizada.');
    state=await rpc('elma_management_data');$('access').textContent='Administrador master';$('panel').classList.remove('hidden');render();
  }catch(e){$('panel').classList.add('hidden');$('access').textContent=e.message;}
}
function render() {
  $('requests').replaceChildren();
  for(const r of state.pendentes){const row=node('div',null,'row'),info=node('div');info.append(node('strong',`A${r.id} • ${r.nome}`),node('p',`${r.funcao||'Função pendente'} • CPF final ${r.cpf_final||'—'} • +${r.phone}`));if(r.proposed_rca)info.append(node('p',`RCA informado: ${r.proposed_rca} • Código atual: ${displayCode(r.codigo)}`));const actions=node('div',null,'actions');if(r.cadastrado)actions.append(button('Aprovar','aprovar',r.id));else info.append(node('p',`Cadastro necessário: use CADASTRAR A${r.id} no WhatsApp administrativo.`));actions.append(button('Negar','negar',r.id));row.append(info,actions);$('requests').append(row);}
  if(!state.pendentes.length)$('requests').append(node('p','Nenhuma autorização pendente.'));
  employees();$('events').replaceChildren();
  $('rh-status').textContent=state.rh_sync?.last_success ? `Sincronização horária ativa. Última atualização: ${new Date(state.rh_sync.last_success).toLocaleString('pt-BR')}. ${state.rh_sync.source_count} colaboradores no RH.` : 'Aguardando a primeira sincronização.';
  $('daily-switch').checked=state.envio_diario?.enabled===true;
  $('daily-status').textContent=state.envio_diario?.enabled ? 'Ativado: vendedores autorizados recebem às 7:30, em dias úteis.' : 'Desativado: nenhum envio automático aos vendedores.';
  for(const e of state.eventos)$('events').append(node('p',`${new Date(e.created_at).toLocaleString('pt-BR')} • ${labels[e.action]||e.action} • registro ${e.target}`));
  if(!state.eventos.length)$('events').append(node('p','Nenhuma alteração registrada pelo painel.'));
}
function displayCode(code){return /^(RH_|COLAB_)/.test(code||'')?'Não atribuído':code||'—';}
function employees(){
  $('employees').replaceChildren();const term=$('search').value.toLocaleLowerCase('pt-BR');
  for(const c of state.colaboradores.filter(c=>`${c.nome} ${c.funcao} ${c.codigo}`.toLocaleLowerCase('pt-BR').includes(term))){const row=node('div',null,'row'),info=node('div');info.append(node('strong',c.nome),node('p',`${c.funcao||'Sem função'} • Código ${displayCode(c.codigo)} • CPF final ${c.cpf_final||'—'}`));
    const actions=node('div',null,'actions'),edit=node('button','Editar cadastro');edit.onclick=()=>{editing=c.id;$('edit-form').reset();$('edit-form').elements.cpf.closest('label').classList.add('hidden');$('edit-form').elements.cpf.required=false;for(const field of ['nome','funcao','codigo','perfil_acesso'])$('edit-form').elements[field].value=c[field]||'';$('edit-form').elements.preservar_rh.checked=c.preservar_rh;$('edit-title').textContent='Editar colaborador';$('edit').showModal();};actions.append(edit);
    const protect=node('label',null,'protect');const check=node('input');check.type='checkbox';check.checked=c.preservar_rh;check.onchange=()=>act('preservar_rh',c.id,{preservar_rh:check.checked});protect.append(check,document.createTextNode(' Preservar cadastro na sincronização do RH'));info.append(protect);
    info.append(node('p',`Permissão no atendimento: ${c.perfil_acesso||'Colaborador'}`));
    if(!c.vinculos.length)info.append(node('p','Sem WhatsApp autorizado.'));
    for(const a of c.vinculos){info.append(node('p',`+${a.phone}${a.admin?' • Administrador das autorizações':''}`));if(!a.admin)actions.append(button('Revogar WhatsApp','revogar',a.id),button('Usar para notificações administrativas','administrador',a.id));}
    row.append(info,actions);$('employees').append(row);
  }
}
async function act(action,id,values={}) {
  if(busy)return;
  const messages={aprovar:'Autorizar este WhatsApp para o colaborador indicado?',negar:'Negar esta solicitação?',revogar:'Revogar o acesso deste WhatsApp?',administrador:'Transferir as notificações e comandos administrativos para este WhatsApp autorizado?',editar:'Salvar as alterações deste colaborador?',cadastrar:'Cadastrar este colaborador?',preservar_rh:values.preservar_rh?'Preservar este cadastro mesmo se o CPF sair da planilha do RH?':'Permitir a exclusão deste cadastro se o CPF estiver ausente do RH?',envio_diario:values.enabled?'Ativar os envios automáticos das 7:30 aos vendedores autorizados?':'Desativar os envios automáticos?'};
  if(!confirm(messages[action])){render();return;}
  busy=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);
  try{await rpc('elma_management_action',{p_action:action,p_id:id,p_values:values});$('feedback').textContent=labels[action]+'.';$('edit').close();await load();}
  catch(e){$('feedback').textContent=e.message;render();}
  finally{busy=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}
}
$('search').oninput=employees;$('refresh').onclick=load;$('cancel').onclick=()=>$('edit').close();
$('edit-form').onsubmit=e=>{e.preventDefault();const values=Object.fromEntries(new FormData(e.currentTarget));values.preservar_rh=e.currentTarget.elements.preservar_rh.checked;act(editing?'editar':'cadastrar',editing||0,values);};
$('new-employee').onclick=()=>{editing=null;$('edit-form').reset();$('edit-form').elements.cpf.closest('label').classList.remove('hidden');$('edit-form').elements.cpf.required=true;$('edit-form').elements.perfil_acesso.value='Colaborador';$('edit-title').textContent='Cadastrar colaborador';$('edit').showModal();};
$('daily-switch').onchange=e=>act('envio_diario',0,{enabled:e.target.checked});
supabase.auth.onAuthStateChange(()=>{$('panel').classList.add('hidden');setTimeout(load,0);});load();
