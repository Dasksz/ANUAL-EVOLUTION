import fs from 'fs';
const appJs = fs.readFileSync('src/js/app.js', 'utf8');

const regex = /\.toFixed\((.*?)\)/g;
let match;
while ((match = regex.exec(appJs)) !== null) {
  const lineNum = appJs.substring(0, match.index).split('\n').length;
  console.log(`Line ${lineNum}: ${match[0]} - ${appJs.substring(match.index - 30, match.index + 20)}`);
}
