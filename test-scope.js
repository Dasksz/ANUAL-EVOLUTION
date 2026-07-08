const acorn = require("acorn");
const fs = require("fs");
const code = fs.readFileSync("src/js/app.js", "utf8");
try {
  acorn.parse(code, { ecmaVersion: 2022, sourceType: "module" });
  console.log("Syntax is valid according to acorn.");
} catch (e) {
  console.error("Syntax error:", e);
}
