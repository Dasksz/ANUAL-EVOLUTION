export const filterKeys = ['filiais','supervisores','vendedores','redes','cidades','pesquisadores'];
const noNetwork = value => value == null || ['', '--', 'N/A', 'N/D'].includes(String(value).trim());
function matches(row,key,value) {
  if (!value) return true;
  if (key === 'redes' && value === 'C/ REDE') return !noNetwork(row[key]);
  if (key === 'redes' && value === 'S/ REDE') return noNetwork(row[key]);
  return row[key] === value;
}
function compatible(row, selected, excluded) {
  return filterKeys.every(key => key === excluded || matches(row,key,selected[key]));
}
export function cascadeFilters(rows, selections, changed) {
  const selected = { ...selections };
  // Give the most recently changed field priority over incompatible old selections.
  const accepted = {};
  const order = changed ? [changed,...filterKeys.filter(k => k !== changed)] : filterKeys;
  for (const key of order) {
    const value = selected[key];
    if (!value) continue;
    if (rows.some(row => compatible(row,{...accepted,[key]:value}))) accepted[key] = value;
    else selected[key] = '';
  }
  const options = {};
  for (const key of filterKeys) {
    const available = rows.filter(row => compatible(row,selected,key));
    const values = [...new Set(available.map(row => row[key]).filter(v => v != null && String(v).trim() && (key !== 'redes' || !noNetwork(v))))].sort((a,b) => a.localeCompare(b,'pt-BR'));
    if (key === 'redes') {
      if (available.some(row => !noNetwork(row.redes))) values.unshift('C/ REDE');
      if (available.some(row => noNetwork(row.redes))) values.unshift('S/ REDE');
    }
    options[key] = values;
  }
  return { selected, options };
}
