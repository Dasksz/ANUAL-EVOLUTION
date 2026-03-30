const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

let lines = content.split('\n');
for(let i=0; i<lines.length; i++) {
    if (lines[i].includes("s.codfor = ANY(ARRAY[''")) {
       console.log("Found at line", i+1, ":", lines[i]);
    }
}
