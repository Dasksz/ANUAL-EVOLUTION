import test from 'node:test';import assert from 'node:assert/strict';
import {portfolioGroups,buildPortfolioPdfs,portfolioZip} from '../src/js/planning-portfolio.mjs';
const row=(code,sellerCode='321',currentMix=0)=>({code,sellerCode,seller:sellerCode==='321'?'RODRIGO SILVA DE MENEZES':'TIAGO',supervisor:'RÔMULO',name:'CLIENTE '+code,city:'JEQUIÉ',currentMix,categoryPresence:[{family:'SALTY',category:'CHEETOS'}]});
const data=()=>({planningDay:'today',planningDate:'2026-11-10',salesThrough:'2026-11-09',rows:[row('1'),row('2','321',1),row('3','318',1)],total:3,categoryCatalog:[{family:'SALTY',category:'CHEETOS'},{family:'SALTY',category:'RUFFLES'},{family:'FOODS',category:'TODDY'}]});
class PDF{constructor(){this.tables=[];this.texts=[];this.lines=[];this.lastAutoTable={finalY:70};}setFillColor(){}rect(){}setFont(){}setFontSize(){}setTextColor(){}setLineWidth(){}setDrawColor(...v){this.color=v;}line(...v){this.lines.push([this.color,v]);}splitTextToSize(s){return [s];}text(s){this.texts.push(s);}addPage(){}setPage(){}getNumberOfPages(){return 1;}autoTable(t){this.tables.push(t);for(let i=0;i<t.body.length;i++)for(let j=0;j<t.head[0].length;j++){const hook={section:'body',row:{index:i},column:{index:j},cell:{x:0,y:0,width:10,height:7,styles:{}}};t.didParseCell?.(hook);t.didDrawCell?.(hook);}}output(){return new TextEncoder().encode('%PDF-test').buffer;}}
test('one named PDF per seller, complete route, red no-sale clients and family-specific check/X',()=>{
 const d=data(),files=buildPortfolioPdfs(d,PDF);assert.equal(files.length,2);const f=files.find(x=>x.sellerCode==='321');assert.match(f.name,/321_RODRIGO_SILVA_DE_MENEZES_2026-11-10.pdf$/);assert.equal(f.pdf.tables[0].body.length,2);assert.ok(f.pdf.texts.some(x=>x.includes('RODRIGO SILVA DE MENEZES')));assert.ok(f.pdf.texts.some(x=>x.includes('Cidades do dia: JEQUIÉ')));assert.equal(f.pdf.tables[0].body[0][3],'SEM COMPRA');assert.ok(f.pdf.lines.some(x=>x[0][1]===130));assert.ok(f.pdf.lines.some(x=>x[0][0]===190));
 for(const title of ['CATEGORIAS SALTY','CATEGORIAS FOODS'])assert.ok(f.pdf.texts.includes(title));
 assert.equal(f.pdf.tables[1].head[0].includes('TODDY'),false);assert.equal(f.pdf.tables[2].head[0].includes('CHEETOS'),false);
});
test('rejects incomplete, stale, blocked-day or pending export rather than creating partial files',()=>{
 for(const change of [{planningDay:'yesterday'},{planningDay:'unrouted'},{salesPending:true},{rosterPending:true},{salesThrough:null},{total:99}])assert.throws(()=>portfolioGroups({...data(),...change}));
 const d=data();d.rows.push(d.rows[0]);d.total++;assert.throws(()=>portfolioGroups(d));assert.throws(()=>buildPortfolioPdfs({...data(),rows:[],total:0},PDF),/Nenhum cliente/);
});
test('large category catalogs split into legible bands without dropping any category',()=>{
 const d=data();d.categoryCatalog=Array.from({length:26},(_,i)=>({family:'SALTY',category:'CAT '+i}));const f=buildPortfolioPdfs(d,PDF)[0];const headers=f.pdf.tables.slice(1).flatMap(x=>x.head[0].slice(1));assert.equal(headers.length,26);assert.equal(new Set(headers).size,26);assert.ok(f.pdf.tables.slice(1).every(t=>t.head[0].length<=9));
});
test('ZIP keeps an independently named PDF entry for every seller',async()=>{const files=buildPortfolioPdfs(data(),PDF),b=new Uint8Array(await portfolioZip(files).arrayBuffer());assert.equal(new DataView(b.buffer).getUint32(0,true),0x04034b50);const text=new TextDecoder().decode(b);for(const f of files)assert.ok(text.includes(f.name));assert.equal(new DataView(b.buffer).getUint16(b.length-12,true),2);});
