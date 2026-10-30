const MESSAGE='Em desenvolvimento. Este painel será disponibilizado após a reunião de fechamento da Inteligência Comercial.';

// Presentation gate for panels under development. Existing Supabase account
// authorization remains responsible for protecting the underlying data.
export function createDevelopmentGate({root,panel,document:doc=root.ownerDocument}){
 const gate=doc.createElement('div');
 gate.className='development-gate';
 gate.innerHTML=`<style>
 .development-gate{position:relative;min-height:470px;border:1px solid #ffffff15;border-radius:16px;overflow:hidden;background:#17151d;color:#eeeaf2;display:grid;place-items:center;padding:32px 20px}
 .development-gate[hidden]{display:none!important}
 .development-gate .dg-censored{position:absolute;inset:30px;filter:blur(9px);opacity:.25;pointer-events:none;user-select:none;display:grid;gap:22px;grid-template-rows:90px 1fr}
 .dg-censored>div{border-radius:12px;background:repeating-linear-gradient(90deg,#756983 0 22%,transparent 22% 26%)}
 .dg-censored>div+div{background:repeating-linear-gradient(0deg,#756983 0 22px,transparent 22px 47px)}
 .development-gate .dg-card{position:relative;width:min(100%,480px);background:#211d29f5;border:1px solid #fb923c35;border-radius:16px;padding:28px;box-shadow:0 18px 60px #0007;text-align:center}
 .dg-lock{display:grid;place-items:center;margin:0 auto 16px;width:44px;height:44px;border-radius:12px;background:#f9731618;color:#fb923c}
 .dg-card p{font-size:14px;line-height:1.7;margin:0 0 24px;color:#e2dce9}
 .dg-card label{display:block;text-align:left;font-size:12px;color:#c0b7cc;margin-bottom:9px;font-weight:600}
 .dg-fields{display:flex;gap:10px}.dg-fields input{min-width:0;flex:1;width:100%;background:#17141e;border:1px solid #ffffff25;border-radius:9px;color:#fff;padding:11px 12px;font-size:16px;letter-spacing:.2em}
 .dg-fields button{background:#f9731620;border:1px solid #f9731660;color:#fdba74;border-radius:9px;padding:11px 16px;cursor:pointer;font-size:13px}
 .dg-fields input:focus-visible,.dg-fields button:focus-visible{outline:2px solid #fb923c;outline-offset:3px}
 .dg-card .dg-error{min-height:20px;margin:10px 0 0;text-align:left;color:#fca5a5;font-size:12px}
 @media(max-width:480px){.development-gate{padding:20px 12px}.development-gate .dg-card{padding:22px 18px}.dg-fields{flex-direction:column}}
 </style><div class="dg-censored" aria-hidden="true"><div></div><div></div></div>
 <form class="dg-card" aria-label="Acesso do Desenvolvedor">
 <span class="dg-lock" aria-hidden="true"><svg width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/><path d="M12 14v3"/></svg></span>
 <p>${MESSAGE}</p><label>Acesso do Desenvolvedor:
 </label><div class="dg-fields"><input type="password" inputmode="numeric" autocomplete="off" aria-label="Acesso do Desenvolvedor:" placeholder="Senha" required><button type="submit">Desbloquear</button></div>
 <p class="dg-error" role="alert" aria-live="polite"></p></form>`;
 root.before(gate);
 const form=gate.querySelector('form'),input=gate.querySelector('input'),error=gate.querySelector('.dg-error');
 // Each panel has its own input/label association.
 const inputId=`${root.id}-developer-password`;
 input.id=inputId;gate.querySelector('label').htmlFor=inputId;
 let active=false,unlocked=false;
 function conceal(){root.hidden=true;root.inert=true;root.setAttribute('aria-hidden','true');}
 function lock(){unlocked=false;conceal();input.value='';error.textContent='';input.removeAttribute('aria-invalid');gate.hidden=!active;}
 form.addEventListener('submit',event=>{
  event.preventDefault();if(!active||unlocked)return;
  if(input.value!=='9128'){input.value='';input.setAttribute('aria-invalid','true');error.textContent='Senha incorreta. Tente novamente.';input.focus();return;}
  unlocked=true;input.value='';error.textContent='';gate.hidden=true;root.hidden=false;root.inert=false;root.removeAttribute('aria-hidden');panel.activate();
 });
 conceal();gate.hidden=true;
 return {
  activate(){if(active)return;active=true;lock();input.focus();},
  deactivate(){active=false;panel.deactivate();lock();}
 };
}
