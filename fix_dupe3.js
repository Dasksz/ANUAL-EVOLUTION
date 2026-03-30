const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const regex2 = /IF p_fornecedor IS NOT NULL AND array_length\(p_fornecedor, 1\) > 0 THEN\s+IF NOT \('ambas' = ANY\(p_fornecedor\)\) THEN\s+v_where_chart := v_where_chart \|\| ' AND \([\s\S]*?END IF;\s+END IF;/g;

let oldMatches = content.match(regex2);
console.log("Found old untouched matches: ", oldMatches ? oldMatches.length : 0);
