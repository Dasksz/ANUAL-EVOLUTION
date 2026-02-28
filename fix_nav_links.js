const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// Looking for the media query block added earlier
const mqStart = html.indexOf('/* Mobile Navbar Adjustments */');

// Checking if it already has .top-nav-links settings
if (mqStart !== -1) {
    console.log("Media query block already exists, checking contents...");
} else {
    console.log("Media query block missing.");
}
