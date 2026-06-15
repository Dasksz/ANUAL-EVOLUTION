import fs from 'fs';
const appJs = fs.readFileSync('src/js/app.js', 'utf8');

// Find function setupDefaultMultiSelect definition
const idx = appJs.indexOf('function setupDefaultMultiSelect');
console.log('Index:', idx);
console.log(appJs.substring(idx - 100, idx + 200));

// Determine if it's inside another function
let braceCount = 0;
for (let i = 0; i < idx; i++) {
  if (appJs[i] === '{') braceCount++;
  if (appJs[i] === '}') braceCount--;
}
console.log('Brace count at definition:', braceCount);
