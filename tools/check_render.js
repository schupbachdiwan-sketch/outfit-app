const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 390, height: 844 });

  await page.goto('http://localhost:8765', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);

  // Take home page screenshot
  await page.screenshot({ path: 'screenshot_1_home.png' });
  console.log('1. Home page screenshot saved');

  // Try to find and click navigation items using Flutter semantics
  const semantics = await page.evaluate(() => {
    const elements = document.querySelectorAll('[aria-label]');
    return Array.from(elements).map(e => e.getAttribute('aria-label')).slice(0, 30);
  });
  console.log('Semantic labels:', semantics);

  // Try clicking on "试衣间" or the second tab
  const tabClicked = await page.evaluate(() => {
    const elements = document.querySelectorAll('flt-semantics');
    for (const el of elements) {
      const label = el.getAttribute('aria-label');
      if (label && label.includes('试衣间')) {
        el.click();
        return 'clicked 试衣间';
      }
    }
    // Try clicking tabs by position - tab buttons are usually at the bottom
    const allButtons = document.querySelectorAll('flt-semantics[role="button"]');
    for (const btn of allButtons) {
      const label = btn.getAttribute('aria-label');
      if (label) console.log('Button:', label);
    }
    return 'not found';
  });
  console.log('Tab click result:', tabClicked);

  await page.waitForTimeout(3000);

  // Screenshot after navigation
  await page.screenshot({ path: 'screenshot_2_nav.png' });
  console.log('2. After navigation screenshot saved');

  await browser.close();
  console.log('Done');
})();
