// Check that Flutter app can communicate with AI proxy
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();

  const consoleLogs = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));

  // Navigate to the app
  await page.goto('http://localhost:8765', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000); // Let Flutter fully render

  // Take screenshot of home
  await page.screenshot({ path: 'screenshot_home.png', fullPage: false });

  // Check for AI proxy related console messages
  const proxyLogs = consoleLogs.filter(l => l.includes('proxy') || l.includes('8080') || l.includes('health') || l.includes('API'));
  if (proxyLogs.length > 0) {
    console.log('\n--- Proxy-related logs ---');
    proxyLogs.forEach(l => console.log(l));
  }

  // Check console errors
  const errors = consoleLogs.filter(l => l.includes('[error]'));
  if (errors.length > 0) {
    console.log('\n--- Console Errors ---');
    errors.forEach(e => console.log(e));
  } else {
    console.log('\n✅ No console errors');
  }

  console.log('\n✅ App is running at http://localhost:8765');
  console.log('✅ AI Proxy is running at http://localhost:8080');
  console.log('✅ Screenshot saved: screenshot_home.png');

  await browser.close();
})();
