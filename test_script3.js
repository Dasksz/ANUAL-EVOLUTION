import fs from 'fs';
const appJs = fs.readFileSync('src/js/app.js', 'utf8');

const regex = /setupDefaultMultiSelect/g;
let match;
let isGlobal = true;
while ((match = regex.exec(appJs)) !== null) {
  let braceCount = 0;
  for (let i = 0; i < match.index; i++) {
    if (appJs[i] === '{') braceCount++;
    if (appJs[i] === '}') braceCount--;
  }
  console.log(`Match at index ${match.index}, brace count: ${braceCount}`);
}
