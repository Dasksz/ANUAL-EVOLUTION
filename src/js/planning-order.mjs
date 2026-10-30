export const IDEAL_SALTY=['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA'];
export const IDEAL_FOODS=['TODDY','TODDYNHO'];
export const IDEAL_CATEGORIES=[...IDEAL_SALTY,...IDEAL_FOODS];
export function idealState(d){
 const actual=d.mixIdeal?(Array.isArray(d.mixIdeal.present)?d.mixIdeal.present:[]):(d.skus||[]).filter(s=>s.current).map(s=>s.idealCategory);
 const present=IDEAL_CATEGORIES.filter(c=>actual.includes(c));
 const saltyCount=IDEAL_SALTY.filter(c=>present.includes(c)).length,foodsCount=IDEAL_FOODS.filter(c=>present.includes(c)).length;
 return {present,missing:IDEAL_CATEGORIES.filter(c=>!present.includes(c)),saltyCount,foodsCount,salty:saltyCount===5,foods:foodsCount===2,achieved:saltyCount===5&&foodsCount===2};
}
const finite=(n,fallback=0)=>Number.isFinite(n)?n:fallback;
const share=s=>Number.isFinite(s.sharePositivity)&&s.sharePositivity>=0?s.sharePositivity:Infinity;
const knownRank=(a,b)=>share(a)-share(b)||finite(b.months)-finite(a.months)||finite(b.averageValue)-finite(a.averageValue)||a.code.localeCompare(b.code,undefined,{numeric:true});
const newRank=(a,b)=>finite(b.penetration)-finite(a.penetration)||share(a)-share(b)||a.code.localeCompare(b.code,undefined,{numeric:true});
export function buildSuggestedOrder(d){
 const ideal=idealState(d),targetMix=Math.max(0,Math.ceil(finite(d.averageMix))),gap=Math.max(0,targetMix-finite(d.currentMix));
 let familySlots=null;
 if(Number.isFinite(d.averageSalty)&&Number.isFinite(d.averageFoods)&&Math.abs(d.averageSalty+d.averageFoods-finite(d.averageMix))<0.00001){
  const targets={SALTY:Math.floor(d.averageSalty),FOODS:Math.floor(d.averageFoods)};
  const remainder=targetMix-targets.SALTY-targets.FOODS;
  if(remainder>0)targets[d.averageSalty-targets.SALTY>=d.averageFoods-targets.FOODS?'SALTY':'FOODS']+=remainder;
  familySlots={SALTY:Math.max(0,targets.SALTY-finite(d.currentSalty)),FOODS:Math.max(0,targets.FOODS-finite(d.currentFoods))};
 }
 const result={ideal,targetMix,gap,rows:[],projectedMix:finite(d.currentMix),uncoveredCategories:[...ideal.missing],blockedReason:null,unfilled:0};
 if(!d.salesThrough){result.blockedReason='Aguardar a carga de vendas do mês antes de sugerir o pedido.';return result;}
 if(d.salesPending){result.blockedReason='Vendas em atualização. A sugestão será recalculada após concluir a carga.';return result;}
 if(ideal.achieved&&gap===0&&(!familySlots||familySlots.SALTY+familySlots.FOODS===0)){result.uncoveredCategories=[];return result;}
 if(!d.historyComplete||!Number.isFinite(d.averageMix)){result.blockedReason='Histórico incompleto: não há base suficiente para dimensionar um pedido.';return result;}
 const existing=new Set((d.skus||[]).map(s=>s.code)),seen=new Set();
 const known=(d.skus||[]).filter(s=>s.months>0&&!s.current).sort(knownRank);
 const novel=(d.suggestions||[]).filter(s=>!existing.has(s.code)&&s.buyers>=3&&s.peers>=5&&s.buyers<=s.peers).sort(newRank);
 const add=(s,kind,purpose)=>{if(!s||seen.has(s.code))return;seen.add(s.code);result.rows.push({...s,kind,purpose,quantityReference:kind==='habitual'&&Number.isFinite(s.averageQuantity)&&s.averageQuantity>0?Math.ceil(s.averageQuantity):null});};
 // Cover missing ideal categories with one item each; known products always come first.
 for(const category of ideal.missing){
  const familiar=known.find(s=>s.idealCategory===category&&!seen.has(s.code));
  if(familiar)add(familiar,'habitual','ideal');
  else add(novel.find(s=>s.idealCategory===category&&!seen.has(s.code)),'segmento','ideal');
 }
 // Only add enough depth to return to the client's historical monthly SKU average.
 if(familySlots)for(const family of ['SALTY','FOODS'])familySlots[family]=Math.max(familySlots[family],result.rows.filter(s=>s.family===family).length);
 const budget=Math.max(gap,result.rows.length,familySlots?familySlots.SALTY+familySlots.FOODS:0);
 const fits=s=>!familySlots||result.rows.filter(r=>r.family===s.family).length<familySlots[s.family];
 for(const s of known){if(result.rows.length>=budget)break;if(fits(s))add(s,'habitual','profundidade');}
 for(const s of novel){if(result.rows.length>=budget)break;if(fits(s))add(s,'segmento','profundidade');}
 result.unfilled=Math.max(0,budget-result.rows.length);
 result.rows.sort((a,b)=>(a.purpose==='ideal'&&a.kind==='habitual'?0:1)-(b.purpose==='ideal'&&b.kind==='habitual'?0:1)||(a.kind===b.kind?0:a.kind==='habitual'?-1:1)||(a.kind==='habitual'?knownRank(a,b):newRank(a,b)));
 const projected=new Set([...ideal.present,...result.rows.map(s=>s.idealCategory)]);
 result.uncoveredCategories=IDEAL_CATEGORIES.filter(c=>!projected.has(c));
 result.projectedMix=finite(d.currentMix)+result.rows.length;
 return result;
}
export function orderReason(s){
 const objective=s.purpose==='ideal'?`Completar ${s.idealCategory} no mix ideal`:'Recompor a profundidade habitual do mix';
 const evidence=s.kind==='habitual'?`comprado em ${s.months} de 3 meses`:`teste de segmento: ${s.buyers} de ${s.peers} clientes`;
 return `${objective}; ${evidence}.`;
}

export function orderStages(order){
 return {complete:order.rows.filter(s=>s.purpose==='ideal'&&s.kind==='habitual'),complement:order.rows.filter(s=>s.purpose!=='ideal'||s.kind!=='habitual')};
}
