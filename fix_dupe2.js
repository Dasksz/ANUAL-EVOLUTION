const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const regex = /IF p_fornecedor IS NOT NULL AND array_length\(p_fornecedor, 1\) > 0 THEN\s+IF NOT \('ambas' = ANY\(p_fornecedor\)\) THEN\s+DECLARE[\s\S]*?END IF;\s+END IF;/g;

let matches = content.match(regex);
console.log("Found matches: ", matches ? matches.length : 0);
