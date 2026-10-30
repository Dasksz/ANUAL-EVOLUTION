import test from 'node:test';
import assert from 'node:assert/strict';
import {buildSuggestedOrder,idealState,IDEAL_CATEGORIES,orderStages} from '../src/js/planning-order.mjs';
const sku=(code,category,share=20,months=2,current=false)=>({code,name:code,family:['TODDY','TODDYNHO'].includes(category)?'FOODS':'SALTY',idealCategory:category,category,sharePositivity:share,months,current,averageValue:100,averageQuantity:2.3,shareBuyers:2,shareBase:10});
const data=()=>({historyComplete:true,salesThrough:'2026-10-29',currentMix:2,averageMix:4,skus:[],suggestions:[],mixIdeal:{present:[]}});
test('historical depth limits the order, rather than returning the entire SKU history',()=>{const d=data();d.skus=Array.from({length:40},(_,i)=>sku(String(i),'CEBOLITOS',i));const p=buildSuggestedOrder(d);assert.equal(p.rows.length,2);assert.equal(p.projectedMix,4);assert.equal(d.skus.length,40);});
test('lower category Share wins among known SKUs, with recurrence breaking ties',()=>{const d=data();d.averageMix=3;d.skus=[sku('popular','CEBOLITOS',90,3),sku('low','SENSACOES',5,1),sku('lower-frequency','CEBOLITOS',5,0)];assert.equal(buildSuggestedOrder(d).rows[0].code,'low');d.skus.push(sku('recurring','SENSACOES',5,3));assert.equal(buildSuggestedOrder(d).rows[0].code,'recurring');});
test('missing ideal categories get one suitable item before extra depth',()=>{const d=data();d.mixIdeal.present=['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA'];d.currentMix=5;d.averageMix=5;d.skus=[sku('toddy','TODDY'),sku('toddy2','TODDY',1),sku('toddynho','TODDYNHO')];const p=buildSuggestedOrder(d);assert.equal(p.rows.length,2);assert.deepEqual(new Set(p.rows.map(s=>s.idealCategory)),new Set(['TODDY','TODDYNHO']));assert.equal(p.ideal.achieved,false);assert.deepEqual(p.uncoveredCategories,[]);});
test('known item wins over a new segment option for the same ideal category',()=>{const d=data();d.skus=[sku('known','TODDY',99)];d.suggestions=[{...sku('new','TODDY',1),buyers:4,peers:10,penetration:40}];assert.equal(buildSuggestedOrder(d).rows.find(s=>s.idealCategory==='TODDY').code,'known');});
test('current-month SKUs never enter the suggested order and duplicate IDs count once',()=>{const d=data();d.skus=[sku('current','CHEETOS',1,3,true),sku('known','DORITOS'),sku('known','DORITOS')];d.suggestions=[{...sku('current','CHEETOS'),buyers:5,peers:10},{...sku('new','TODDY'),buyers:4,peers:10}];const p=buildSuggestedOrder(d);assert.ok(!p.rows.some(s=>s.code==='current'));assert.equal(p.rows.filter(s=>s.code==='known').length,1);assert.equal(p.rows.find(s=>s.code==='known').quantityReference,3);assert.equal(p.rows.find(s=>s.code==='new').quantityReference,null);});
test('Quaker and Kerococo neither complete Foods nor prevent the achieved classification',()=>{const d=data();d.mixIdeal.present=[...IDEAL_CATEGORIES];d.currentMix=7;assert.equal(idealState(d).achieved,true);assert.equal(idealState(d).foodsCount,2);assert.equal(buildSuggestedOrder(d).rows.length,0);d.mixIdeal.present=['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA','QUAKER','KEROCOCO'];assert.equal(idealState(d).foods,false);assert.deepEqual(idealState(d).missing,['TODDY','TODDYNHO']);});
test('the projected order does not classify the client as already ideal',()=>{const d=data();d.skus=IDEAL_CATEGORIES.map(c=>sku(c,c));const p=buildSuggestedOrder(d);assert.equal(p.rows.length,7);assert.equal(p.ideal.achieved,false);assert.equal(idealState(d).achieved,false);assert.deepEqual(p.uncoveredCategories,[]);});
test('missing Share remains unknown and sorts after measured categories, including zero',()=>{const d=data();d.skus=[sku('unknown','OUTROS',null),sku('zero','SENSACOES',0),sku('ten','OUTROS',10)];assert.deepEqual(buildSuggestedOrder(d).rows.map(s=>s.code),['zero','ten']);});
test('unavailable or incomplete data produces no speculative order',()=>{for(const change of [{historyComplete:false},{salesThrough:null},{salesPending:true}]){const d={...data(),...change,skus:[sku('a','TODDY')]};const p=buildSuggestedOrder(d);assert.equal(p.rows.length,0);assert.ok(p.blockedReason);}});

test('achieved classification remains true while historical depth can still justify a small order',()=>{const d=data();d.mixIdeal.present=[...IDEAL_CATEGORIES];d.currentMix=7;d.averageMix=9;d.skus=[sku('a','SENSACOES',10),sku('b','CEBOLITOS',20),sku('c','OUTROS',30)];const p=buildSuggestedOrder(d);assert.equal(p.ideal.achieved,true);assert.equal(p.rows.length,2);assert.equal(p.projectedMix,9);});
test('low Share does not overfill Foods at the expense of the historical family profile',()=>{const d=data();Object.assign(d,{averageMix:10,averageSalty:8,averageFoods:2,currentMix:7,currentSalty:6,currentFoods:1});d.mixIdeal.present=[...IDEAL_CATEGORIES];d.skus=[sku('food1','TODDY',1),sku('food2','TODDYNHO',2),sku('salty1','CHEETOS',30),sku('salty2','DORITOS',40)];const p=buildSuggestedOrder(d);assert.equal(p.rows.length,3);assert.equal(p.rows.filter(s=>s.family==='FOODS').length,1);assert.equal(p.rows.filter(s=>s.family==='SALTY').length,2);});
test('stage one prioritizes habitual ideal coverage ahead of lower Share depth and novel suggestions',()=>{
 const d=data();d.averageMix=7;d.mixIdeal.present=['CHEETOS','DORITOS','FANDANGOS','RUFFLES'];
 d.skus=[sku('torcida','TORCIDA',90),sku('toddy','TODDY',70),sku('depth','SENSACOES',1),sku('repeat','TODDY',80)];
 d.suggestions=[{...sku('novel','TODDYNHO',2),buyers:4,peers:10,penetration:40}];
 const p=buildSuggestedOrder(d),s=orderStages(p);
 assert.deepEqual(s.complete.map(x=>x.code),['toddy','torcida']);
 assert.deepEqual(s.complement.map(x=>x.code),['depth','repeat','novel']);
 assert.deepEqual(p.rows.map(x=>x.code),[...s.complete,...s.complement].map(x=>x.code));
 assert.equal(new Set(p.rows.map(x=>x.code)).size,p.rows.length);assert.equal(p.projectedMix,7);
});
test('achieved clients have no stage one and no-history categories never masquerade as habitual',()=>{
 const d=data();d.mixIdeal.present=[...IDEAL_CATEGORIES];d.skus=[sku('depth','SENSACOES')];
 let s=orderStages(buildSuggestedOrder(d));assert.equal(s.complete.length,0);assert.equal(s.complement.length,1);
 d.mixIdeal.present=[];d.skus=[];d.suggestions=[{...sku('new','TODDY'),months:0,buyers:4,peers:10}];
 s=orderStages(buildSuggestedOrder(d));assert.equal(s.complete.length,0);assert.equal(s.complement[0].purpose,'ideal');
});
