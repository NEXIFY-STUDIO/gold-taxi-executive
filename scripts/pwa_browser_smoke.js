const { chromium } = require('@playwright/test');

const forbiddenPatterns = [
  'firebase',
  'firestore',
  'identitytoolkit',
  'securetoken',
  'googleapis',
  'supabase',
  '/api/',
  'auth',
];

function matchesSensitiveRuntimePath(url) {
  const pathname = new URL(url).pathname.toLowerCase();
  return [
    pathname === '/app' || pathname.startsWith('/app/'),
    pathname.includes('/booking'),
    pathname.includes('/login'),
    pathname.includes('/tracking'),
    pathname.includes('/payment'),
    pathname.includes('/account'),
  ].some(Boolean);
}

async function snapshotCaches(page) {
  return page.evaluate(async () => {
    const keys = await caches.keys();
    const entries = [];

    for (const key of keys) {
      const cache = await caches.open(key);
      const requests = await cache.keys();
      for (const request of requests) {
        entries.push(request.url);
      }
    }

    return { keys, entries };
  });
}

async function main() {
  const baseUrl = process.env.PWA_SMOKE_BASE_URL || 'https://gold-taxi-clean.web.app';
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  const diagnostics = [];

  page.on('console', (message) => {
    diagnostics.push(`console ${message.type()}: ${message.text()}`);
  });
  page.on('pageerror', (error) => {
    diagnostics.push(`pageerror: ${error.stack || error.message}`);
  });
  page.on('requestfailed', (request) => {
    diagnostics.push(
      `requestfailed: ${request.url()} ${JSON.stringify(request.failure())}`,
    );
  });

  try {
    const offlineResponse = await page.request.get(`${baseUrl}/offline.html`);
    if (offlineResponse.status() !== 200) {
      throw new Error(`/offline.html returned ${offlineResponse.status()}`);
    }

    await page.goto(`${baseUrl}/?browser-smoke=${Date.now()}`, {
      waitUntil: 'domcontentloaded',
      timeout: 25_000,
    });

    const registrationState = await page.evaluate(async () => {
      const swApiAvailable = 'serviceWorker' in navigator;
      if (!swApiAvailable) {
        return { swApiAvailable, hasRegistration: false };
      }

      if (window.goldTaxiServiceWorkerReady) {
        await window.goldTaxiServiceWorkerReady;
      }

      const registration = await navigator.serviceWorker.getRegistration('/');

      return {
        swApiAvailable,
        hasRegistration: Boolean(registration),
        scope: registration?.scope || null,
        activeScriptURL: registration?.active?.scriptURL || null,
        waitingScriptURL: registration?.waiting?.scriptURL || null,
        installingScriptURL: registration?.installing?.scriptURL || null,
      };
    });

    if (!registrationState.swApiAvailable) {
      throw new Error('Service worker API is not available in the browser context.');
    }

    if (!registrationState.hasRegistration) {
      throw new Error(
        [
          'The production page did not passively register a service worker.',
          ...diagnostics.slice(-20),
        ].join('\n'),
      );
    }

    await page.reload({
      waitUntil: 'domcontentloaded',
      timeout: 15_000,
    });

    await page.waitForFunction(
      () => 'serviceWorker' in navigator && Boolean(navigator.serviceWorker.controller),
      null,
      { timeout: 15_000 },
    );

    const beforeOffline = await snapshotCaches(page);
    verifyCachedEntries(beforeOffline.entries);

    await context.setOffline(true);
    await page.goto(`${baseUrl}/offline-smoke-${Date.now()}`, {
      waitUntil: 'commit',
      timeout: 15_000,
    });
    await page.waitForTimeout(2_000);

    const bodyText = await page.locator('body').innerText();
    if (!bodyText.includes('Ste offline. Verejná časť aplikácie je dostupná iba čiastočne.')) {
      throw new Error('Offline navigation did not render the offline fallback page.');
    }

    const afterOffline = await snapshotCaches(page);
    if (afterOffline.keys.length === 0) {
      throw new Error('Cache Storage is empty after offline shell initialization.');
    }
    verifyCachedEntries(afterOffline.entries);

    console.log('PWA browser smoke passed');
    console.log(`Base URL: ${baseUrl}`);
    console.log(`Service worker scope: ${registrationState.scope}`);
    console.log(`Service worker script: ${registrationState.activeScriptURL || registrationState.waitingScriptURL || registrationState.installingScriptURL}`);
    console.log(`Cached entries checked: ${afterOffline.entries.length}`);
  } finally {
    await browser.close();
  }
}

function verifyCachedEntries(entries) {
  for (const url of entries) {
    const lower = url.toLowerCase();

    for (const pattern of forbiddenPatterns) {
      if (lower.includes(pattern)) {
        throw new Error(`Forbidden cache pattern "${pattern}" found in ${url}`);
      }
    }

    if (matchesSensitiveRuntimePath(url)) {
      throw new Error(`Sensitive runtime path found in cache: ${url}`);
    }
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
