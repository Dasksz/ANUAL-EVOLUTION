const { JSDOM } = require("jsdom");
const fs = require("fs");
const html = fs.readFileSync("index.html", "utf8");
const appJs = fs.readFileSync("src/js/app.js", "utf8");

const dom = new JSDOM(html, {
  runScripts: "dangerously",
  resources: "usable"
});

// Since it's module, JSDOM might not run it perfectly directly if we just append the string,
// but we can just evaluate it inside a <script> block and mock the imports.
// It's probably overkill.
console.log("JSDOM ready");
