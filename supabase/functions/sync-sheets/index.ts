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
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

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
        headers: { "Content-Type": "application/json", ...corsHeaders },
        status: 400
      });
    }

    const records = [];
    for (let i = 1; i < lines.length; i++) {
      if (!lines[i].trim()) continue;
      
      const columns = parseCSVLine(lines[i]);
      // A data está no índice 2 e supervisor no 4 baseados no cabeçalho
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

    console.log(`Parsed ${records.length} valid records. Connecting to Supabase...`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    
    if (!supabaseUrl || !supabaseKey) {
       throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);
    
    console.log("Truncating existing data from supervisors_routes...");
    const { error: cleanError } = await supabase
      .from('supervisors_routes')
      .delete()
      .neq('supervisor', 'INEXISTENTE_ZZZ');

    if (cleanError) {
        console.error("Error cleaning table:", cleanError);
        throw new Error(`Failed to clean table: ${cleanError.message}`);
    }

    console.log("Inserting new data into supervisors_routes...");
    // Pode ser inserido em chunks caso seja muito grande, mas 1460 cabe num só request
    const { data, error } = await supabase
      .from('supervisors_routes')
      .insert(records);

    if (error) {
      throw error;
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: `Successfully cleaned and inserted ${records.length} records.`,
      records_synced: records.length
    }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
      status: 200
    });

  } catch (error) {
    console.error("Error syncing sheets:", error);
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
      status: 500
    });
  }
});
