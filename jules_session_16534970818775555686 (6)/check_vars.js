const fs = require('fs');

const code = fs.readFileSync('src/js/app.js', 'utf8');
const lines = code.split('\n');

const definitions = new Map();
const usages = [];

// Simplified regex, assumes standard formatting `const varName = document.getElementById(...)` or similar
const defRegex = /const\s+([a-zA-Z0-9_]+)\s*=\s*document\.getElementById/g;
const wordRegex = /[a-zA-Z0-9_]+/g;

lines.forEach((line, index) => {
    let match;
    // Find definitions
    while ((match = defRegex.exec(line)) !== null) {
        const varName = match[1];
        if (!definitions.has(varName)) {
            definitions.set(varName, index); // Store line number (0-indexed)
        }
    }
});

let possibleErrors = [];

// Now find usages
lines.forEach((line, index) => {
    // skip comments to reduce false positives
    if (line.trim().startsWith('//')) return;
    
    let match;
    while ((match = wordRegex.exec(line)) !== null) {
        const word = match[0];
        if (definitions.has(word)) {
            const defLine = definitions.get(word);
            // If the variable is used before it is defined, AND it is inside the DOMContentLoaded scope (which executes sequentially), it's a ReferenceError.
            // Since all this is inside an async function or DOMContentLoaded, we just do a basic sequential check.
            if (index < defLine) {
                 possibleErrors.push({ varName: word, defLine: defLine + 1, usedLine: index + 1 });
            }
        }
    }
});

if (possibleErrors.length > 0) {
    console.log("Found potential uses before definition:");
    const uniqueErrors = [...new Map(possibleErrors.map(item => [item.varName, item])).values()];
    console.table(uniqueErrors);
} else {
    console.log("No obvious use-before-definition errors found!");
}
