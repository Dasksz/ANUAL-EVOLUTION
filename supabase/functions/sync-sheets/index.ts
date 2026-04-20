import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SHEET_URL = "https://docs.google.com/spreadsheets/d/1NcS5wBwNwp8_32wZAots2L1LxZ0dTW_kL7S7TyM6ZbM/export?format=csv&gid=0";

function parseBrazilianDate(dateStr: string): string | null {
  if (!dateStr) return null;
  // Ex: 01-janeiro-26
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
    console.log("Fetching CSV from Google Sheets...");
    const response = await fetch(SHEET_URL);

    if (!response.ok) {
      throw new Error(`Failed to fetch sheet: ${response.status} ${response.statusText}`);
    }

    const csvText = await response.text();
    const lines = csvText.split('\n');

    if (lines.length < 2) {
      return new Response(JSON.stringify({ message: "Empty or invalid CSV" }), {
        headers: { "Content-Type": "application/json" },
        status: 400
      });
    }

    // Skip header (index 0)
    const records = [];
    for (let i = 1; i < lines.length; i++) {
      if (!lines[i].trim()) continue;

      const columns = parseCSVLine(lines[i]);
      if (columns.length < 4 || !columns[1] || !columns[3]) continue; // needs date and supervisor at least

      const parsedDate = parseBrazilianDate(columns[1]);
      if (!parsedDate) continue;

      records.push({
        cargo: columns[0] || null,
        data_rota: parsedDate,
        dia_semana: columns[2] || null,
        supervisor: columns[3] || null,
        rota_dia: columns[4] || null,
        clientes_roteirizados: columns[5] ? parseInt(columns[5], 10) : null,
        acompanhado_dia_codigo: columns[6] || null,
        foco_dia: columns[7] || null,
        clientes_visitados: columns[8] ? parseInt(columns[8], 10) : null,
        clientes_com_venda: columns[9] ? parseInt(columns[9], 10) : null,
        observacao_rota: columns[10] || null,
        eficiencia_visita: columns[11] || null,
        eficiencia_rota: columns[12] || null,
        eficiencia_saida: columns[13] || null
      });
    }

    console.log(`Parsed ${records.length} valid records. Connecting to Supabase...`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !supabaseKey) {
       throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    console.log("Upserting data into supervisors_routes...");
    const { data, error } = await supabase
      .from('supervisors_routes')
      .upsert(records, { onConflict: 'data_rota,supervisor' });

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({
      success: true,
      message: `Successfully synced ${records.length} records.`,
      records_synced: records.length
    }), {
      headers: { "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error("Error syncing sheets:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      headers: { "Content-Type": "application/json" },
      status: 500
    });
  }
});
