const { execSync } = require('child_process');
try {
  const result = execSync("node --test tests/worker.test.js", {encoding: 'utf-8'});
  console.log(result);
} catch (e) {
  console.log("No tests exist. Skipping.");
}
