import supabase from './supabase.js?v=5';
import { samePortfolioConfig } from './portfolio-config.mjs';

export async function mountSpecialPortfolios(panel) {
 const nav=document.createElement('nav');
 nav.className='actions';nav.setAttribute('aria-label','Seções da gestão');
 const general=document.createElement('button'),special=document.createElement('button');
 general.textContent='Gestão';special.textContent='Carteiras especiais';
 const existing=[...panel.children];
 const section=document.createElement('section');section.hidden=true;
 section.innerHTML='<h2>Carteiras especiais</h2><h3>Vendedor BH</h3><p>Supervisor: Balcão. A meta vem do vendedor 53 na planilha. As vendas dos clientes vinculados compõem BH, o supervisor Balcão e a empresa.</p><p>Os percentuais distribuem a meta entre os clientes e devem somar 100%. Positivação e mix preservam contagens inteiras. Cada configuração vale a partir do mês informado até a próxima configuração.</p><label>Configurações salvas<select data-versions></select></label><form><label>Aplicar a partir de<input type="month" required data-month min="2000-01" max="2100-12"></label><div data-rows></div><button type="button" data-add>Adicionar cliente</button><p data-total></p><button class="primary" type="submit">Salvar configuração</button></form><p role="status" aria-live="polite" data-status></p>';
 nav.append(general,special);panel.prepend(nav);panel.append(section);
 function show(active){for(const el of existing)el.hidden=active;section.hidden=!active;general.setAttribute('aria-pressed',String(!active));special.setAttribute('aria-pressed',String(active));}
 general.onclick=()=>show(false);special.onclick=()=>show(true);show(false);
 const rows=section.querySelector('[data-rows]'),status=section.querySelector('[data-status]'),month=section.querySelector('[data-month]'),versions=section.querySelector('[data-versions]');
 let data=[],saving=false;
 function total(){const sum=[...rows.querySelectorAll('[data-percent]')].reduce((a,e)=>a+Math.round(Number(e.value||0)*100),0);section.querySelector('[data-total]').textContent=`Total: ${(sum/100).toLocaleString('pt-BR')}%`;return sum;}
 function add(code='',percent=''){
  const row=document.createElement('div');row.className='grid';
  const codeLabel=document.createElement('label');codeLabel.textContent='Código do cliente';
  const input=document.createElement('input');input.required=true;input.pattern='[0-9]+';input.inputMode='numeric';input.value=code;input.dataset.code='';codeLabel.append(input);
  const pctLabel=document.createElement('label');pctLabel.textContent='Percentual da meta';
  const pct=document.createElement('input');pct.type='number';pct.min='0.01';pct.max='100';pct.step='0.01';pct.required=true;pct.value=percent;pct.dataset.percent='';pct.oninput=total;pctLabel.append(pct);
  const remove=document.createElement('button');remove.type='button';remove.textContent='Remover';remove.onclick=()=>{row.remove();total();};
  row.append(codeLabel,pctLabel,remove);rows.append(row);total();
 }
 section.querySelector('[data-add]').onclick=()=>add();
 function selectVersion(){const v=data[Number(versions.value)];if(!v)return;month.value=String(v.start_ym).slice(0,4)+'-'+String(v.start_ym).slice(4);rows.replaceChildren();for(const c of v.clients)add(c.code,c.percent);}
 function render(){versions.replaceChildren();data.forEach((v,i)=>{const opt=document.createElement('option');opt.value=i;opt.textContent=`A partir de ${String(v.start_ym).slice(4)}/${String(v.start_ym).slice(0,4)}`;versions.append(opt);});versions.value=String(data.length-1);selectVersion();}
 versions.onchange=selectVersion;
 async function call(args={}){const {data,error}=await supabase.rpc('bh_portfolio_config',args);if(error)throw Error(error.message);return data;}
 section.querySelector('form').onsubmit=async event=>{
  event.preventDefault();if(saving)return;
  if(total()!==10000){status.textContent='Os percentuais devem somar exatamente 100%.';return;}
  const clients=[...rows.children].map(row=>({code:row.querySelector('[data-code]').value.trim(),percent:Number(row.querySelector('[data-percent]').value)}));
  if(new Set(clients.map(c=>c.code)).size!==clients.length){status.textContent='Cada cliente deve aparecer uma única vez.';return;}
  const startYm=Number(month.value.replace('-',''));
  if(samePortfolioConfig(data,startYm,clients)){status.textContent='Nenhuma alteração para salvar.';return;}
  saving=true;for(const el of section.querySelectorAll('button,input,select'))el.disabled=true;
  status.textContent='Salvando e atualizando metas, vendas e filtros…';
  try{data=await call({p_start_ym:startYm,p_clients:clients});render();status.textContent='Configuração salva. Metas, vendas e filtros atualizados. Atualize o dashboard aberto para consultar os resultados.';}
  catch(e){status.textContent=`Não foi possível salvar: ${e.message}`;}
  finally{saving=false;for(const el of section.querySelectorAll('button,input,select'))el.disabled=false;}
 };
 try{data=await call();render();}catch(e){status.textContent=e.message;}
}
