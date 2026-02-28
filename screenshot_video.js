const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    recordVideo: { dir: 'videos/', size: { width: 1920, height: 1080 } }
  });
  const page = await context.newPage();

  await page.goto(`file://${__dirname}/index.html`);

  await page.evaluate(() => {
    // Hide login, show dashboard for visualization
    document.getElementById('login-view').classList.add('hidden');
    document.getElementById('app-layout').classList.remove('hidden');
    document.getElementById('top-navbar').classList.remove('hidden');
  });

  // Wait a few seconds to capture the animation
  await page.waitForTimeout(4000);

  await browser.close();
})();
