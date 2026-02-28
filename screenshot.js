const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1920, height: 1080 }
  });

  await page.goto(`file://${__dirname}/index.html`);

  // Wait a moment for styles to load
  await page.waitForTimeout(1000);

  await page.evaluate(() => {
    // Hide login, show dashboard for visualization
    document.getElementById('login-view').classList.add('hidden');
    document.getElementById('app-layout').classList.remove('hidden');
    document.getElementById('top-navbar').classList.remove('hidden');
  });

  // Capture a small video to show the animation (or just take a screenshot)
  await page.screenshot({ path: 'dashboard_with_animated_lines.png' });

  await browser.close();
})();
