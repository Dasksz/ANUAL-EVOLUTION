const clean=v=>String(v??'').replace(/[\x00-\x1f]/g,' ').trim();
const filename=v=>clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9_-]+/g,'_').slice(0,90);
const day=v=>new Date(v+'T12:00:00Z').toLocaleDateString('pt-BR',{timeZone:'UTC'});
export function portfolioGroups(data){
 if(!data||!['today','tomorrow'].includes(data.planningDay)||data.salesPending||data.rosterPending||!data.salesThrough)throw Error('Aguarde uma carteira válida de hoje ou amanhã para exportar.');
 if(!Array.isArray(data.rows)||data.rows.length!==data.total||!Array.isArray(data.categoryCatalog))throw Error('A exportação não recebeu a carteira completa. Atualize e tente novamente.');
 const groups=new Map(),seen=new Set();
 for(const row of data.rows){
  if(!row.code||!row.sellerCode||!Number.isFinite(row.currentMix)||!Array.isArray(row.categoryPresence)||seen.has(row.code))throw Error('Cliente inválido ou duplicado na exportação.');
  seen.add(row.code);if(!groups.has(row.sellerCode))groups.set(row.sellerCode,{code:row.sellerCode,name:row.seller,supervisor:row.supervisor,clients:[]});groups.get(row.sellerCode).clients.push(row);
 }
 return [...groups.values()].sort((a,b)=>a.name.localeCompare(b.name,'pt-BR')).map(g=>({...g,clients:g.clients.sort((a,b)=>(a.city||'').localeCompare(b.city||'','pt-BR')||a.name.localeCompare(b.name,'pt-BR'))}));
}
export function buildPortfolioPdfs(data,PDF){
 if(!PDF)throw Error('PDF indisponível. Atualize a página e tente novamente.');
 const groups=portfolioGroups(data);if(!groups.length)throw Error('Nenhum cliente na rota com os filtros selecionados.');
 return groups.map(group=>{
  const pdf=new PDF({orientation:'landscape',unit:'mm',format:'a4'}),width=297,height=210,margin=13;let y=21;
  const banner=()=>{pdf.setFillColor(25,24,31);pdf.rect(0,0,width,9,'F');pdf.setFillColor(249,115,22);pdf.rect(0,9,width,1,'F');};banner();
  function paragraph(text,size=10,bold=false){pdf.setFont('helvetica',bold?'bold':'normal');pdf.setFontSize(size);pdf.setTextColor(40,38,45);const lines=pdf.splitTextToSize(clean(text),width-margin*2);for(const line of lines){if(y>height-22){pdf.addPage();banner();y=21;}pdf.text(line,margin,y);y+=size*.45;}y+=3;}
  paragraph('PLANEJAMENTO DE ROTA - '+day(data.planningDate),17,true);
  paragraph(group.code+' - '+group.name,14,true);paragraph('Supervisor: '+group.supervisor);
  paragraph('Cidades do dia: '+[...new Set(group.clients.map(c=>c.city||'Não informada'))].join(' / '));
  paragraph(`${group.clients.length} clientes na rota | ${group.clients.filter(c=>c.currentMix===0).length} sem compra no mês | Vendas até ${day(data.salesThrough)}`);
  if(data.status&&data.status!=='all')paragraph('Recorte: '+({'no-sale':'Sem compra no mês',ideal:'Mix ideal alcançado',purchased:'Com compra no mês'})[data.status]);
  if(data.search)paragraph('Busca aplicada: '+data.search);
  const base={margin:{left:margin,right:margin,top:18,bottom:16},styles:{font:'helvetica',fontSize:8,cellPadding:2.4,overflow:'linebreak'},headStyles:{fillColor:[38,34,44],textColor:255},rowPageBreak:'avoid',didDrawPage:banner};
  function title(text){if(y>height-44){pdf.addPage();banner();y=21;}paragraph(text,12,true);}
  title('CLIENTES DA ROTA');
  pdf.autoTable({...base,startY:y,head:[['Código','Cliente','Cidade','Compra no mês']],body:group.clients.map(c=>[clean(c.code),clean(c.name),clean(c.city),c.currentMix===0?'SEM COMPRA':'Positivado']),columnStyles:{0:{cellWidth:19},2:{cellWidth:53},3:{cellWidth:35}},didParseCell:h=>{if(h.section==='body'&&group.clients[h.row.index].currentMix===0){h.cell.styles.fillColor=[254,235,234];h.cell.styles.textColor=[155,35,35];}}});y=pdf.lastAutoTable.finalY+10;
  paragraph('Categorias: check verde = compra no mês; X vermelho = sem compra na categoria. Clientes sem compra no mês destacados em vermelho.',9);
  for(const family of ['SALTY','FOODS']){
   const categories=[...new Set(data.categoryCatalog.filter(c=>c.family===family).map(c=>clean(c.category)))].filter(Boolean).sort((a,b)=>a.localeCompare(b,'pt-BR'));
   if(!categories.length){title('CATEGORIAS '+family);paragraph('Sem categorias cadastradas para esta família.');continue;}
   for(let start=0;start<categories.length;start+=8){
    const chunk=categories.slice(start,start+8);title('CATEGORIAS '+family+(categories.length>8?` - ${Math.floor(start/8)+1}/${Math.ceil(categories.length/8)}`:''));
    pdf.autoTable({...base,startY:y,head:[['Cliente',...chunk]],body:group.clients.map(c=>[clean(c.code)+' - '+clean(c.name),...chunk.map(()=> '')]),styles:{...base.styles,fontSize:7.5,halign:'center'},columnStyles:{0:{cellWidth:73,halign:'left'}},
     didParseCell:h=>{if(h.section==='body'&&h.column.index===0&&group.clients[h.row.index].currentMix===0){h.cell.styles.fillColor=[254,235,234];h.cell.styles.textColor=[155,35,35];}},
     didDrawCell:h=>{if(h.section!=='body'||h.column.index===0)return;const c=group.clients[h.row.index],category=chunk[h.column.index-1],ok=c.categoryPresence.some(p=>p.family===family&&p.category===category),x=h.cell.x+h.cell.width/2,z=h.cell.y+h.cell.height/2;pdf.setLineWidth(.5);pdf.setDrawColor(...(ok?[22,130,82]:[190,55,55]));if(ok){pdf.line(x-1.7,z,x-.4,z+1.3);pdf.line(x-.4,z+1.3,x+2,z-1.5);}else{pdf.line(x-1.3,z-1.3,x+1.3,z+1.3);pdf.line(x-1.3,z+1.3,x+1.3,z-1.3);}}});y=pdf.lastAutoTable.finalY+10;
   }
  }
  const pages=pdf.getNumberOfPages();for(let i=1;i<=pages;i++){pdf.setPage(i);pdf.setFont('helvetica','normal');pdf.setFontSize(8);pdf.setTextColor(110,105,115);pdf.text('PRIME | '+clean(group.name)+' | '+day(data.planningDate),margin,height-7);pdf.text(`${i} / ${pages}`,width-margin,height-7,{align:'right'});}
  return {pdf,name:`Planejamento_${filename(group.code)}_${filename(group.name)}_${data.planningDate}.pdf`,sellerCode:group.code};
 });
}
// Store-mode ZIP: one PDF per seller, one browser download, UTF-8 names.
export function portfolioZip(files){
 const enc=new TextEncoder(),chunks=[],central=[];let offset=0,size=0;
 const crc=bytes=>{let c=0xffffffff;for(const b of bytes){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;};
 const header=(length)=>{const bytes=new Uint8Array(length);return[bytes,new DataView(bytes.buffer)];};
 for(const f of files){const name=enc.encode(f.name),bytes=new Uint8Array(f.pdf.output('arraybuffer')),checksum=crc(bytes);const[h,v]=header(30);v.setUint32(0,0x04034b50,true);v.setUint16(4,20,true);v.setUint16(6,0x800,true);v.setUint16(12,33,true);v.setUint32(14,checksum,true);v.setUint32(18,bytes.length,true);v.setUint32(22,bytes.length,true);v.setUint16(26,name.length,true);chunks.push(h,name,bytes);const[c,w]=header(46);w.setUint32(0,0x02014b50,true);w.setUint16(4,20,true);w.setUint16(6,20,true);w.setUint16(8,0x800,true);w.setUint16(14,33,true);w.setUint32(16,checksum,true);w.setUint32(20,bytes.length,true);w.setUint32(24,bytes.length,true);w.setUint16(28,name.length,true);w.setUint32(42,offset,true);central.push(c,name);offset+=30+name.length+bytes.length;size+=46+name.length;}
 const[e,v]=header(22);v.setUint32(0,0x06054b50,true);v.setUint16(8,files.length,true);v.setUint16(10,files.length,true);v.setUint32(12,size,true);v.setUint32(16,offset,true);return new Blob([...chunks,...central,e],{type:'application/zip'});
}
