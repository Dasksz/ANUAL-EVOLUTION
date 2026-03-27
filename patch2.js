const fs = require('fs');
const file = 'src/js/app.js';
let content = fs.readFileSync(file, 'utf8');

const targetStr = `
                        updateStatus(\`Processando \${m}/\${year} (Parte 1/3)...\`, progress + Math.round(monthStep * 0.10));
                        const res1 = await supabase.rpc('refresh_summary_chunk', { p_start_date: startDate, p_end_date: chunk1EndDate });
                        if (res1.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 1): \${res1.error.message}\`);

                        updateStatus(\`Processando \${m}/\${year} (Parte 2/3)...\`, progress + Math.round(monthStep * 0.20));
                        const res2 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk1EndDate, p_end_date: chunk2EndDate });
                        if (res2.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 2): \${res2.error.message}\`);

                        updateStatus(\`Processando \${m}/\${year} (Parte 3/3)...\`, progress + Math.round(monthStep * 0.30));
                        const res3 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk2EndDate, p_end_date: endDate });
                        if (res3.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 3): \${res3.error.message}\`);
`;

const replaceStr = `
                        updateStatus(\`Processando \${m}/\${year} (Parte 1/3)...\`, progress + Math.round(monthStep * 0.10));
                        await retryOperation(async () => {
                            const res1 = await supabase.rpc('refresh_summary_chunk', { p_start_date: startDate, p_end_date: chunk1EndDate });
                            if (res1.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 1): \${res1.error.message}\`);
                        }, 3, 2000);

                        updateStatus(\`Processando \${m}/\${year} (Parte 2/3)...\`, progress + Math.round(monthStep * 0.20));
                        await retryOperation(async () => {
                            const res2 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk1EndDate, p_end_date: chunk2EndDate });
                            if (res2.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 2): \${res2.error.message}\`);
                        }, 3, 2000);

                        updateStatus(\`Processando \${m}/\${year} (Parte 3/3)...\`, progress + Math.round(monthStep * 0.30));
                        await retryOperation(async () => {
                            const res3 = await supabase.rpc('refresh_summary_chunk', { p_start_date: chunk2EndDate, p_end_date: endDate });
                            if (res3.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 3): \${res3.error.message}\`);
                        }, 3, 2000);
`;

if (content.includes(targetStr.trim())) {
    content = content.replace(targetStr.trim(), replaceStr.trim());
    fs.writeFileSync(file, content, 'utf8');
    console.log('Patch 2 applied successfully.');
} else {
    console.log('Target string 2 not found.');
}
