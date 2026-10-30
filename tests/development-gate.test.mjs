import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createDevelopmentGate} from '../src/js/development-gate.mjs';

function harness(id='planning-content'){
 const elements=new Map();
 class El{
  constructor(){this.events={};this.attrs={};this.value='';}
  querySelector(k){if(!elements.has(k))elements.set(k,new El());return elements.get(k);}
  addEventListener(k,fn){this.events[k]=fn;}
  setAttribute(k,v){this.attrs[k]=v;}
  removeAttribute(k){delete this.attrs[k];}
  before(el){this.gate=el;}
  focus(){this.focused=true;}
 }
 const root=new El();root.id=id;let loads=0,stops=0;
 const panel=createDevelopmentGate({root,panel:{activate(){loads++;},deactivate(){stops++;}},document:{createElement(){return new El();}}});
 const input=elements.get('input');
 return {root,panel,input,elements,get loads(){return loads;},get stops(){return stops;},submit(password){input.value=password;elements.get('form').events.submit({preventDefault(){}});}};
}
test('locked panels never activate data loading; wrong passwords retain censorship',()=>{
 const h=harness();h.panel.activate();assert.equal(h.loads,0);assert.equal(h.root.hidden,true);assert.equal(h.root.inert,true);assert.equal(h.root.gate.hidden,false);
 assert.match(h.root.gate.innerHTML,/Em desenvolvimento\. Este painel será disponibilizado após a reunião de fechamento da Inteligência Comercial\./);
 assert.match(h.root.gate.innerHTML,/Acesso do Desenvolvedor:/);
 h.submit('1234');assert.equal(h.loads,0);assert.equal(h.root.hidden,true);assert.equal(h.input.value,'');assert.match(h.elements.get('.dg-error').textContent,/Senha incorreta/);
});
test('correct password activates once and leaving locks subsequent entries',()=>{
 const h=harness();h.panel.activate();h.submit('9128');assert.equal(h.loads,1);assert.equal(h.root.hidden,false);assert.equal(h.root.inert,false);assert.equal(h.root.gate.hidden,true);assert.equal(h.input.value,'');
 h.submit('9128');assert.equal(h.loads,1);h.panel.deactivate();assert.equal(h.stops,1);assert.equal(h.root.hidden,true);h.submit('9128');assert.equal(h.loads,1);
 h.panel.activate();assert.equal(h.root.gate.hidden,false);assert.equal(h.root.hidden,true);h.submit('9128');assert.equal(h.loads,2);
});
test('unlocking one panel does not authorize the other',()=>{
 const planning=harness(),health=harness('commercial-health-content');planning.panel.activate();planning.submit('9128');health.panel.activate();assert.equal(health.loads,0);assert.equal(health.root.hidden,true);assert.equal(planning.loads,1);
});
test('navigation and direct URL routes both use wrapped panels and logout locks them',()=>{
 const app=readFileSync(new URL('../src/js/app.js',import.meta.url),'utf8');
 assert.match(app,/const planningPanel = createDevelopmentGate\(/);assert.match(app,/const commercialHealthPanel = createDevelopmentGate\(/);
 assert.match(app,/case 'planning':[\s\S]*?planningPanel\.activate\(\)/);assert.match(app,/case 'commercial-health':[\s\S]*?commercialHealthPanel\.activate\(\)/);
 assert.match(app,/if \(event === 'SIGNED_OUT'\) \{\s*planningPanel\.deactivate\(\);\s*commercialHealthPanel\.deactivate\(\)/);
});
