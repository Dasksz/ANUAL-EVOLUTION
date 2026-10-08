import supabase from './supabase.js?v=5';
const $ = id => document.getElementById(id);
let state, editing, busy = false;
const labels = {aprovar:'Autorização aprovada',negar:'Autorização negada',revogar:'WhatsApp revogado',administrador:'WhatsApp administrativo alterado',editar:'Cadastro atualizado'};
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
  for(const r of state.pendentes){const row=node('div',null,'row'),info=node('div');info.append(node('strong',`A${r.id} • ${r.nome}`),node('p',`${r.funcao||'Função pendente'} • CPF final ${r.cpf_final||'—'} • +${r.phone}`));const actions=node('div',null,'actions');if(r.cadastrado)actions.append(button('Aprovar','aprovar',r.id));else info.append(node('p',`Cadastro necessário: use CADASTRAR A${r.id} no WhatsApp administrativo.`));actions.append(button('Negar','negar',r.id));row.append(info,actions);$('requests').append(row);}
  if(!state.pendentes.length)$('requests').append(node('p','Nenhuma autorização pendente.'));
  employees();$('events').replaceChildren();
  for(const e of state.eventos)$('events').append(node('p',`${new Date(e.created_at).toLocaleString('pt-BR')} • ${labels[e.action]||e.action} • registro ${e.target}`));
  if(!state.eventos.length)$('events').append(node('p','Nenhuma alteração registrada pelo painel.'));
}
function employees(){
  $('employees').replaceChildren();const term=$('search').value.toLocaleLowerCase('pt-BR');
  for(const c of state.colaboradores.filter(c=>`${c.nome} ${c.funcao} ${c.codigo}`.toLocaleLowerCase('pt-BR').includes(term))){const row=node('div',null,'row'),info=node('div');info.append(node('strong',c.nome),node('p',`${c.funcao||'Sem função'} • Código ${c.codigo||'—'} • CPF final ${c.cpf_final||'—'}`));
    const actions=node('div',null,'actions'),edit=node('button','Editar cadastro');edit.onclick=()=>{editing=c.id;for(const field of ['nome','funcao','codigo'])$('edit-form').elements[field].value=c[field]||'';$('edit').showModal();};actions.append(edit);
    if(!c.vinculos.length)info.append(node('p','Sem WhatsApp autorizado.'));
    for(const a of c.vinculos){info.append(node('p',`+${a.phone}${a.admin?' • Administrador das autorizações':''}`));if(!a.admin)actions.append(button('Revogar WhatsApp','revogar',a.id),button('Usar para notificações administrativas','administrador',a.id));}
    row.append(info,actions);$('employees').append(row);
  }
}
async function act(action,id,values={}) {
  if(busy)return;
  const messages={aprovar:'Autorizar este WhatsApp para o colaborador indicado?',negar:'Negar esta solicitação?',revogar:'Revogar o acesso deste WhatsApp?',administrador:'Transferir as notificações e comandos administrativos para este WhatsApp autorizado?',editar:'Salvar as alterações deste colaborador?'};
  if(!confirm(messages[action]))return;
  busy=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);
  try{await rpc('elma_management_action',{p_action:action,p_id:id,p_values:values});$('feedback').textContent=labels[action]+'.';$('edit').close();await load();}
  catch(e){$('feedback').textContent=e.message;}
  finally{busy=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);}
}
$('search').oninput=employees;$('refresh').onclick=load;$('cancel').onclick=()=>$('edit').close();
$('edit-form').onsubmit=e=>{e.preventDefault();act('editar',editing,Object.fromEntries(new FormData(e.currentTarget)));};
supabase.auth.onAuthStateChange(()=>{$('panel').classList.add('hidden');setTimeout(load,0);});load();
