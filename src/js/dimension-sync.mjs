const fields = {
  dim_supervisores: ['codigo', 'nome'],
  dim_vendedores: ['codigo', 'nome'],
  dim_fornecedores: ['codigo', 'nome'],
  dim_produtos: ['codigo', 'descricao', 'codfor', 'qtde_embalagem_master', 'dt_cadastro']
};

function value(field, input) {
  if (input == null) return null;
  if (field === 'qtde_embalagem_master' && input !== '' && Number.isFinite(Number(input))) return String(Number(input));
  if (field === 'dt_cadastro') {
    const date = new Date(input);
    if (Number.isFinite(date.getTime())) return date.toISOString().slice(0, 10);
  }
  return String(input);
}

// Compare only fields the upload actually supplies; omitted columns remain intact.
// Each lookup has at most 200 unique primary keys, below the API row limit.
export async function changedDimensionRows(client, table, rows) {
  if (!rows?.length) return [];
  const allowed = fields[table];
  if (!allowed) throw Error('Cadastro inválido para comparação.');
  const columns = new Set(['codigo']);
  const codes = new Set();
  for (const row of rows) {
    if (row.codigo == null || String(row.codigo) === '' || codes.has(String(row.codigo))) throw Error('Código de cadastro inválido ou duplicado.');
    codes.add(String(row.codigo));
    for (const key of Object.keys(row)) {
      if (!allowed.includes(key)) throw Error('Campo de cadastro não reconhecido: ' + key);
      if (row[key] !== undefined) columns.add(key);
    }
  }
  const existing = new Map();
  const keys = [...codes];
  for (let offset = 0; offset < keys.length; offset += 200) {
    const { data, error } = await client.from(table).select([...columns].join(',')).in('codigo', keys.slice(offset, offset + 200));
    if (error || !Array.isArray(data)) throw Error(`Erro ao conferir ${table}: ${error?.message || 'resposta inválida'}`);
    for (const row of data) existing.set(String(row.codigo), row);
  }
  return rows.filter(row => {
    const before = existing.get(String(row.codigo));
    return !before || Object.keys(row).some(key => row[key] !== undefined && value(key, row[key]) !== value(key, before[key]));
  });
}

// Raw client records still sync in full. Only these attributes feed stored sales
// summaries/goal portfolios; last-purchase dates and contact data are read live.
export async function clientSummaryNeedsRefresh(client, rows) {
  if (!rows?.length) return false;
  const projected = ['rca1', 'codsupervisor', 'cidade', 'ramo'];
  const incoming = new Map();
  for (const row of rows) {
    const code = row.codigo_cliente;
    if (code == null || code === '' || incoming.has(String(code))) throw Error('Código de cliente inválido ou duplicado.');
    incoming.set(String(code), row);
  }
  let count = 0;
  let changed = false;
  for (let offset = 0; ; offset += 1000) {
    const {data, error} = await client.from('data_clients').select('codigo_cliente,' + projected.join(','))
      .order('codigo_cliente').range(offset, offset + 999);
    if (error || !Array.isArray(data)) throw Error('Erro ao conferir cadastro dos clientes: ' + (error?.message || 'resposta inválida'));
    for (const before of data) {
      count++;
      const row = incoming.get(String(before.codigo_cliente));
      if (!row || projected.some(key => value(key, row[key]) !== value(key, before[key]))) changed = true;
    }
    if (data.length < 1000) break;
  }
  return changed || count !== incoming.size;
}
