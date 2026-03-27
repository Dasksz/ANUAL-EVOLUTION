const fs = require('fs');
const file = 'src/js/app.js';
let content = fs.readFileSync(file, 'utf8');

const targetStr = `
                        updateStatus(\`Processando \${m}/\${year} em paralelo...\`, progress + Math.round(monthStep * 0.30));
                        const [res1, res2, res3] = await Promise.all([
                            supabase.rpc('refresh_summary_chunk', { p_start_date: startDate, p_end_date: chunk1EndDate }),
                            supabase.rpc('refresh_summary_chunk', { p_start_date: chunk1EndDate, p_end_date: chunk2EndDate }),
                            supabase.rpc('refresh_summary_chunk', { p_start_date: chunk2EndDate, p_end_date: endDate })
                        ]);

                        if (res1.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 1): \${res1.error.message}\`);
                        if (res2.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 2): \${res2.error.message}\`);
                        if (res3.error) throw new Error(\`Erro processando \${m}/\${year} (Parte 3): \${res3.error.message}\`);
`;

const replaceStr = `
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

if (content.includes(targetStr.trim())) {
    content = content.replace(targetStr.trim(), replaceStr.trim());
    fs.writeFileSync(file, content, 'utf8');
    console.log('Patch applied successfully.');
} else {
    console.log('Target string not found.');
    // Try regex

    const re = /updateStatus\(\`Processando \$\{m\}\/\$\{year\} em paralelo...\`, progress \+ Math.round\(monthStep \* 0.30\)\);[\s\S]*?if \(res3\.error\) throw new Error\(\`Erro processando \$\{m\}\/\$\{year\} \(Parte 3\): \$\{res3\.error\.message\}\`\);/g;

    if (re.test(content)) {
        content = content.replace(re, replaceStr.trim());
        fs.writeFileSync(file, content, 'utf8');
        console.log('Regex patch applied successfully.');
    } else {
        console.log("Could not patch.");
    }
}
