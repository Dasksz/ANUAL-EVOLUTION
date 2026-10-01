// This rule identifies a seller; supervisor fields must never be used here.
export function isVendorRankingEligible(row) {
  const code = row.codusur ?? row.codigo_vendedor ?? row.vendedor_codigo ?? row.CODUSUR;
  if (code != null && String(code).trim()) return String(code).trim().replace(/^0+/, '') !== '190';
  const name = row.vendedor ?? row.vendedor_nome ?? row.NOME;
  return String(name ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().replace(/\s+/g, ' ').toUpperCase() !== 'TIAGO JOSE DE SOUZA GOMES';
}
