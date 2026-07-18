// Playwright script to drive the Flutter web app
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 }, // iPhone 14 size
  });
  const page = await context.newPage();

  // Collect console messages
  const consoleLogs = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));

  // Navigate to the app
  console.log('Navigating to http://localhost:8765 ...');
  await page.goto('http://localhost:8765', { waitUntil: 'networkidle', timeout: 30000 });
  console.log('Page loaded.');

  // Wait for Flutter to render (Flutter web mounts a <flt-glass-pane> or similar)
  await page.waitForTimeout(3000);

  // Take screenshot of initial page
  await page.screenshot({ path: 'screenshot_home.png', fullPage: false });
  console.log('Screenshot saved: screenshot_home.png');

  // Print page title
  const title = await page.title();
  console.log(`Page title: "${title}"`);

  // Print body HTML structure (first 2000 chars)
  const bodyHTML = await page.evaluate(() => document.body.innerHTML.substring(0, 2000));
  console.log('\n--- Body HTML (first 2000 chars) ---');
  console.log(bodyHTML);

  // Check console errors
  const errors = consoleLogs.filter(l => l.includes('[error]'));
  if (errors.length > 0) {
    console.log('\n--- Console Errors ---');
    errors.forEach(e => console.log(e));
  } else {
    console.log('\nNo console errors found.');
  }

  // Try clicking around — look for bottom nav items
  const navItems = await page.evaluate(() => {
    const elements = document.querySelectorAll('flt-semantics');
    return Array.from(elements).map(e => e.getAttribute('aria-label')).filter(Boolean).slice(0, 20);
  });
  console.log('\n--- Semantic labels found ---');
  console.log(navItems.join(', ') || 'None found');

  await browser.close();
  console.log('\nDone.');
})();
