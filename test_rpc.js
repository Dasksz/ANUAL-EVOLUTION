const SUPABASE_URL = 'https://vawrdqreibhlfsfvxbpv.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhd3JkcXJlaWJobGZzZnZ4YnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwNzg1MTAsImV4cCI6MjA4MjY1NDUxMH0.-mAobZK_dc3QOwey3Z8NbrtybWPoPRfBqW_IN0gehl8';

async function run() {
    const filters = {
        p_ano: null,
        p_mes: null,
        p_filial: null,
        p_cidade: null,
        p_supervisor: null,
        p_vendedor: null,
        p_fornecedor: null,
        p_tipovenda: null,
        p_rede: null,
        p_categoria: null
    };

    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_estrelas_kpis_data`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`
        },
        body: JSON.stringify(filters)
    });

    if (!res.ok) {
        console.error("HTTP Error", res.status, await res.text());
        return;
    }

    const data = await res.json();
    console.log("Success!", JSON.stringify(data).substring(0, 100));
}

run();
