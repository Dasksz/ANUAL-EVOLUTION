import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.11.0";
import { parse } from "https://deno.land/std@0.177.0/encoding/csv.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // Using service role to bypass RLS for background job

const MIX_URL = "https://docs.google.com/spreadsheets/d/1wIF9UzPlyRFnt6MQh-kG9VuMD22Mcwiu/export?format=csv";
const INOVACOES_URL = "https://docs.google.com/spreadsheets/d/1F1NTWFYTCvRvS0xeITKFxjnmLoUYicow/export?format=csv";

serve(async (req) => {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        console.log("Iniciando sincronização de Mix e Inovações...");

        // --- 1. Sincronizar Mix Ideal ---
        console.log("Baixando Planilha Mix Ideal...");
        const mixResponse = await fetch(MIX_URL);
        const mixCsvText = await mixResponse.text();
        const mixData = parse(mixCsvText, { skipFirstRow: true });

        // Limpar tabela atual
        await supabase.from('mix_ideal').delete().neq('id', 0);

        // Formatar e Inserir
        // Acessando as colunas conforme elas vêm no CSV (precisamos mapear pelo índice se não tiver header exato,
        // mas assumindo colunas 0=Categoria, etc base nas regras do prompt. O parse() com skipFirstRow tenta retornar um array de objetos ou arrays.)
        // Se skipFirstRow=true, retorna arrays.
        const mixInserts = mixData.map(row => {
            return {
                nome_categoria: row[0] || "",
                produto_obrigatorio: row[1] || "",
                cod_categoria: row[2] || "M" + Math.floor(Math.random() * 1000) // fallback
            };
        }).filter(r => r.nome_categoria.trim() !== "");

        if (mixInserts.length > 0) {
            await supabase.from('mix_ideal').insert(mixInserts);
            console.log(`Mix inserido: ${mixInserts.length} linhas.`);
        }

        // --- 2. Sincronizar Inovações ---
        console.log("Baixando Planilha Inovações...");
        const inovResponse = await fetch(INOVACOES_URL);
        const inovCsvText = await inovResponse.text();
        const inovData = parse(inovCsvText, { skipFirstRow: true });

        await supabase.from('inovacoes').delete().neq('id', 0);

        const inovInserts = inovData.map(row => {
            return {
                cod_produto: row[0] || "",
                nome_produto: row[1] || "",
                categoria_inovacao: row[2] || ""
            };
        }).filter(r => r.cod_produto.trim() !== "");

        if (inovInserts.length > 0) {
            await supabase.from('inovacoes').insert(inovInserts);
            console.log(`Inovações inseridas: ${inovInserts.length} linhas.`);
        }

        // --- 3. Registrar Sucesso ---
        await supabase.from('import_logs').insert({
            job_name: 'sync_mix_inovacoes',
            status: 'SUCCESS',
            records_processed: mixInserts.length + inovInserts.length
        });

        return new Response(JSON.stringify({ success: true, mix_rows: mixInserts.length, inovacoes_rows: inovInserts.length }), {
            headers: { "Content-Type": "application/json" },
            status: 200
        });

    } catch (error) {
        console.error("Erro na sincronização:", error);

        // Registrar Erro
        await supabase.from('import_logs').insert({
            job_name: 'sync_mix_inovacoes',
            status: 'ERROR',
            error_message: error.toString()
        });

        return new Response(JSON.stringify({ success: false, error: error.message }), {
            headers: { "Content-Type": "application/json" },
            status: 500
        });
    }
});
