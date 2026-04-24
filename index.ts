import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SHEET_URL = "https://docs.google.com/spreadsheets/d/1NcS5wBwNwp8_32wZAots2L1LxZ0dTW_kL7S7TyM6ZbM/export?format=csv&gid=0";

function parseBrazilianDate(dateStr: string): string | null {
  if (!dateStr) return null;
  const parts = dateStr.split('-');
  if (parts.length !== 3) return null;

  const day = parts[0].padStart(2, '0');
  const monthStr = parts[1].toLowerCase();

  const months: Record<string, string> = {
    'janeiro': '01', 'fevereiro': '02', 'março': '03', 'marco': '03',
    'abril': '04', 'maio': '05', 'junho': '06', 'julho': '07',
    'agosto': '08', 'setembro': '09', 'outubro': '10', 'novembro': '11', 'dezembro': '12'
  };

  const month = months[monthStr] || '01';
  let year = parts[2];
  if (year.length === 2) {
    year = '20' + year;
  }

  return `${year}-${month}-${day}`;
}

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current);
  return result.map(s => s.trim().replace(/^"|"$/g, ''));
}

Deno.serve(async (req) => {
  try {
    const response = await fetch(SHEET_URL);
    if (!response.ok) {
      throw new Error(`Failed to fetch sheet: ${response.status}`);
    }
    const csvText = await response.text();
    const lines = csvText.split('\n');
    const records = [];
    for (let i = 1; i < lines.length; i++) {
      if (!lines[i].trim()) continue;
      const columns = parseCSVLine(lines[i]);
      if (columns.length < 5 || !columns[2] || !columns[4]) continue;

      const parsedDate = parseBrazilianDate(columns[2]);
      if (!parsedDate) continue;

      records.push({
        cargo: columns[0] || null,
        acompanhado_dia_codigo: columns[1] || null,
        data_rota: parsedDate,
        dia_semana: columns[3] || null,
        supervisor: columns[4] || null,
        rota_dia: columns[5] || null,
        acompanhado_dia_nome: columns[6] || null,
        clientes_roteirizados: columns[7] ? parseInt(columns[7], 10) : null,
        foco_dia: columns[8] || null,
        clientes_visitados: columns[9] ? parseInt(columns[9], 10) : null,
        clientes_com_venda: columns[10] ? parseInt(columns[10], 10) : null,
        observacao_rota: columns[11] || null,
        eficiencia_visita: columns[12] || null,
        eficiencia_rota: columns[13] || null,
        eficiencia_saida: columns[14] || null
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data, error } = await supabase.from('supervisors_routes').upsert(records, { onConflict: 'data_rota,supervisor' });
    if (error) throw error;

    return new Response(JSON.stringify({ success: true, records_synced: records.length }), { headers: { "Content-Type": "application/json" }, status: 200 });
  } catch (error: any) {
    return new Response(JSON.stringify({ success: false, error: error.message }), { headers: { "Content-Type": "application/json" }, status: 500 });
  }
});
