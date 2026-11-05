export function samePortfolioConfig(versions, startYm, clients) {
 const saved=versions.find(v=>Number(v.start_ym)===Number(startYm));
 const key=items=>JSON.stringify(items.map(c=>[String(c.code).trim(),Number(c.percent)]).sort((a,b)=>a[0].localeCompare(b[0])));
 return !!saved && key(saved.clients)===key(clients);
}
