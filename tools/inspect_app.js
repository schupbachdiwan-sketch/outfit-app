// Drive Flutter app and screenshot the fitting room
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();

  // Navigate to app
  await page.goto('http://localhost:8765', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(4000);

  // Screenshot home page
  await page.screenshot({ path: 'screenshot_home.png' });
  console.log('Home screenshot saved');

  // Check the canvas element
  const canvasInfo = await page.evaluate(() => {
    const flutterView = document.querySelector('flutter-view');
    if (!flutterView) return { error: 'No flutter-view found' };
    const rect = flutterView.getBoundingClientRect();
    return {
      width: rect.width,
      height: rect.height,
      innerHTML: flutterView.innerHTML.substring(0, 500),
    };
  });
  console.log('Flutter view:', JSON.stringify(canvasInfo, null, 2));

  // Look for any image elements or canvas elements
  const allElements = await page.evaluate(() => {
    const imgs = document.querySelectorAll('img');
    const canvases = document.querySelectorAll('canvas');
    const result = {
      images: Array.from(imgs).map(i => ({
        src: i.src.substring(0, 80),
        width: i.width,
        height: i.height,
        naturalWidth: i.naturalWidth,
        naturalHeight: i.naturalHeight,
      })),
      canvases: Array.from(canvases).map(c => ({
        width: c.width,
        height: c.height,
      })),
    };
    return result;
  });
  console.log('Elements:', JSON.stringify(allElements, null, 2));

  // Check if there's a canvas with image rendering
  const canvasData = await page.evaluate(() => {
    const canvases = document.querySelectorAll('canvas');
    if (canvases.length === 0) return 'No canvas elements';
    const c = canvases[0];
    return `Canvas: ${c.width}x${c.height}, style: ${c.style.width}x${c.style.height}`;
  });
  console.log(canvasData);

  await browser.close();
})();
