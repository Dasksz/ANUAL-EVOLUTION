import test from 'node:test';import assert from 'node:assert/strict';
import {portfolioGroups,buildPortfolioPdfs,portfolioZip} from '../src/js/planning-portfolio.mjs';
const row=(code,sellerCode='321',currentMix=0)=>({code,sellerCode,seller:sellerCode==='321'?'RODRIGO SILVA DE MENEZES':'TIAGO',supervisor:'RÔMULO',name:'CLIENTE '+code,city:'JEQUIÉ',currentMix,currentValue:currentMix?1234.56:0,averageValue:1500,revenueGoal:2000,overdue:false,categoryPresence:[{family:'SALTY',category:'CHEETOS'}]});
const data=()=>({month:'2026-11',planningDay:'today',planningDate:'2026-11-10',salesThrough:'2026-11-09',rows:[row('1'),row('2','321',1),row('3','318',1)],total:3,categoryCatalog:[{family:'SALTY',category:'CHEETOS'},{family:'SALTY',category:'RUFFLES'},{family:'FOODS',category:'TODDY'}]});
class PDF{constructor(){this.tables=[];this.texts=[];this.lines=[];this.lastAutoTable={finalY:70};}setFillColor(){}rect(){}setFont(){}setFontSize(){}setTextColor(){}setLineWidth(){}setDrawColor(...v){this.color=v;}line(...v){this.lines.push([this.color,v]);}splitTextToSize(s){return [s];}text(s){this.texts.push(s);}addPage(){}setPage(){}getNumberOfPages(){return 1;}autoTable(t){this.tables.push(t);for(let i=0;i<t.body.length;i++)for(let j=0;j<t.head[0].length;j++){const hook={section:'body',row:{index:i},column:{index:j},cell:{x:0,y:0,width:10,height:7,styles:{}}};t.didParseCell?.(hook);t.didDrawCell?.(hook);}}output(){return new TextEncoder().encode('%PDF-test').buffer;}}
test('one named PDF per seller, complete route, red no-sale clients and family-specific check/X',()=>{
 const d=data(),files=buildPortfolioPdfs(d,PDF);assert.equal(files.length,2);const f=files.find(x=>x.sellerCode==='321');assert.match(f.name,/321_RODRIGO_SILVA_DE_MENEZES_2026-11-10.pdf$/);assert.equal(f.pdf.tables[0].body.length,1);assert.equal(f.pdf.tables[1].body.length,1);assert.ok(f.pdf.texts.some(x=>x.includes('RODRIGO SILVA DE MENEZES')));assert.ok(f.pdf.texts.some(x=>x.includes('Cidades do dia: JEQUIÉ')));assert.ok(f.pdf.texts.includes('CLIENTES SEM COMPRA NO MÊS (1)'));assert.ok(f.pdf.texts.includes('CLIENTES POSITIVADOS NO MÊS (1)'));assert.ok(f.pdf.lines.some(x=>x[0][1]===130));assert.ok(f.pdf.lines.some(x=>x[0][0]===190));
 for(const title of ['CATEGORIAS SALTY','CATEGORIAS FOODS'])assert.ok(f.pdf.texts.includes(title));
 assert.equal(f.pdf.tables[2].head[0].includes('TODDY'),false);assert.equal(f.pdf.tables[3].head[0].includes('CHEETOS'),false);
});
test('rejects incomplete, stale, blocked-day or pending export rather than creating partial files',()=>{
 for(const change of [{planningDay:'yesterday'},{planningDay:'unrouted'},{salesPending:true},{rosterPending:true},{salesThrough:null},{total:99}])assert.throws(()=>portfolioGroups({...data(),...change}));
 const d=data();d.rows.push(d.rows[0]);d.total++;assert.throws(()=>portfolioGroups(d));assert.throws(()=>buildPortfolioPdfs({...data(),rows:[],total:0},PDF),/Nenhum cliente/);
});
test('Salty exports one table with only five ideal brands, using the same classification as the panel',()=>{
 const d=data();d.categoryCatalog.push(...Array.from({length:26},(_,i)=>({family:'SALTY',category:'CAT '+i})));
 d.rows[0].mixIdeal={present:['CHEETOS','DORITOS']};d.rows[0].categoryPresence=[{family:'SALTY',category:'CHEETOS CRUNCHY'}];
 const f=buildPortfolioPdfs(d,PDF).find(f=>f.sellerCode==='321');
 assert.deepEqual(f.pdf.tables[2].head[0],['Cliente','CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA']);
 assert.equal(f.pdf.texts.filter(t=>t.startsWith('CATEGORIAS SALTY')).length,1);assert.equal(f.pdf.tables.length,4);
 assert.equal(f.pdf.lines.slice(0,4).every(x=>x[0][1]===130),true);
});
test('ZIP keeps an independently named PDF entry for every seller',async()=>{const files=buildPortfolioPdfs(data(),PDF),b=new Uint8Array(await portfolioZip(files).arrayBuffer());assert.equal(new DataView(b.buffer).getUint32(0,true),0x04034b50);const text=new TextDecoder().decode(b);for(const f of files)assert.ok(text.includes(f.name));assert.equal(new DataView(b.buffer).getUint16(b.length-12,true),2);});


test('positivated clients show ideal brand counts, excluding extra SKUs and duplicated brands',()=>{
 const d=data();d.rows[1].mixIdeal={present:['CHEETOS','DORITOS','FANDANGOS','RUFFLES','TORCIDA','QUAKER','TODDY','TODDYNHO','KEROCOCO','CHEETOS','OUTROS']};
 const f=buildPortfolioPdfs(d,PDF).find(x=>x.sellerCode==='321');assert.equal(f.pdf.tables[1].body[0][7],'Salty 5/5 - Foods 4/4');
 d.rows[1].mixIdeal.present=['CHEETOS','TORCIDA','TODDY'];const partial=buildPortfolioPdfs(d,PDF).find(x=>x.sellerCode==='321');assert.equal(partial.pdf.tables[1].body[0][7],'Salty 2/5 - Foods 1/4');
 assert.deepEqual(portfolioGroups(d).find(x=>x.code==='321').clients.map(x=>x.code),['1','2']);
});


test('both client sections include financial amounts and strict Sim/Não, preserving missing and zero goals',()=>{
 const d=data();d.rows[0].overdue=true;d.rows[0].revenueGoal=null;d.rows[1].revenueGoal=0;
 const f=buildPortfolioPdfs(d,PDF).find(x=>x.sellerCode==='321');
 for(const t of f.pdf.tables.slice(0,2))for(const label of ['Média trim.','Meta','Realizado','Inadimplente'])assert.ok(t.head[0].includes(label));
 const noSale=f.pdf.tables[0].body[0],positive=f.pdf.tables[1].body[0];assert.equal(noSale[4],'—');assert.equal(noSale[6],'Sim');assert.match(noSale[5],/0,00/);assert.match(positive[4],/0,00/);assert.equal(positive[6],'Não');assert.match(positive[5],/1.234,56/);
 const invalid=data();delete invalid.rows[0].overdue;assert.throws(()=>buildPortfolioPdfs(invalid,PDF));
});
