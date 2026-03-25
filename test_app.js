const fs = require('fs');
let code = fs.readFileSync('src/js/app.js', 'utf8');

// I'm suspecting that I replaced `[]` with `null` globally but maybe some function expected `[]` and crashed on `null.length`?
// Let's search for `length` in app.js where the variable could be null because of my change.

let lines = code.split('\n');
lines.forEach((l, i) => {
    if (l.includes('.length') && l.includes('?')) {
        // console.log(`${i+1}: ${l}`);
    }
});
