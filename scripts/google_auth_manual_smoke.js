const { chromium } = require('@playwright/test');
const readline = require('node:readline/promises');
const { stdin: input, stdout: output } = require('node:process');

const baseUrl =
  process.env.GOOGLE_AUTH_SMOKE_BASE_URL || 'https://gold-taxi-clean.web.app';
const screenshotPath =
  process.env.GOOGLE_AUTH_SMOKE_SCREENSHOT ||
  '/tmp/goldtaxi-google-auth-smoke.png';

function relevantFailedRequests(requests) {
  return requests.filter((request) => {
    if (request.url.includes('/assets/FontManifest.json')) {
      return false;
    }
    if (
      request.url.includes('firestore.googleapis.com') &&
      request.url.includes('/Listen/channel') &&
      request.failure === 'net::ERR_ABORTED'
    ) {
      return false;
    }
    return true;
  });
}

async function detectFirebaseAuth(page) {
  return page.evaluate(async () => {
    if (!('indexedDB' in window) || !indexedDB.databases) {
      return { checked: false, signedIn: false, providerIds: [] };
    }

    const databases = await indexedDB.databases();
    const authDb = databases.find((db) => db.name === 'firebaseLocalStorageDb');
    if (!authDb?.name) {
      return { checked: true, signedIn: false, providerIds: [] };
    }

    return new Promise((resolve) => {
      const request = indexedDB.open(authDb.name);
      request.onerror = () =>
        resolve({ checked: true, signedIn: false, providerIds: [] });
      request.onsuccess = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains('firebaseLocalStorage')) {
          db.close();
          resolve({ checked: true, signedIn: false, providerIds: [] });
          return;
        }

        const transaction = db.transaction('firebaseLocalStorage', 'readonly');
        const store = transaction.objectStore('firebaseLocalStorage');
        const getAll = store.getAll();
        getAll.onerror = () => {
          db.close();
          resolve({ checked: true, signedIn: false, providerIds: [] });
        };
        getAll.onsuccess = () => {
          const providerIds = new Set();
          let signedIn = false;
          for (const entry of getAll.result || []) {
            const value = entry?.value;
            const providers = value?.providerData || [];
            for (const provider of providers) {
              if (provider?.providerId) {
                providerIds.add(provider.providerId);
              }
            }
            if (providers.length > 0 || value?.uid) {
              signedIn = true;
            }
          }
          db.close();
          resolve({
            checked: true,
            signedIn,
            providerIds: Array.from(providerIds),
          });
        };
      };
    });
  });
}

async function main() {
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: false,
    args: ['--window-size=1440,1000'],
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
  });
  const page = await context.newPage();
  const diagnostics = {
    consoleErrors: [],
    pageErrors: [],
    failedRequests: [],
    badResponses: [],
  };

  page.on('console', (message) => {
    if (message.type() === 'error') {
      diagnostics.consoleErrors.push(message.text());
    }
  });
  page.on('pageerror', (error) => {
    diagnostics.pageErrors.push(error.stack || error.message);
  });
  page.on('requestfailed', (request) => {
    diagnostics.failedRequests.push({
      url: request.url(),
      failure: request.failure()?.errorText || null,
    });
  });
  page.on('response', (response) => {
    if (response.status() >= 400) {
      diagnostics.badResponses.push({
        url: response.url(),
        status: response.status(),
      });
    }
  });

  await page.goto(`${baseUrl}/app`, {
    waitUntil: 'domcontentloaded',
    timeout: 45_000,
  });
  await page.waitForTimeout(5_000);

  console.log('');
  console.log('GoldTaxi Google Auth Manual Smoke');
  console.log(`App URL: ${baseUrl}/app`);
  console.log('');
  console.log('1. Click "Sign in with Google" in the opened Chrome window.');
  console.log('2. Select your Google account.');
  console.log('3. Wait until the app returns to /app.');
  console.log('4. Confirm visually that Driver and Ops tabs are not visible.');
  console.log('');

  const rl = readline.createInterface({ input, output });
  await rl.question('Press Enter here after Google sign-in returns to the app...');
  rl.close();

  await page.waitForTimeout(3_000);
  await page.screenshot({ path: screenshotPath, fullPage: true });

  const renderState = await page.evaluate(() => ({
    href: window.location.href,
    readyState: document.readyState,
    loadingExists: Boolean(document.querySelector('#loading')),
    hasFlutterView: Boolean(
      document.querySelector('flutter-view') ||
        document.querySelector('flt-glass-pane') ||
        document.querySelector('[data-flutter-view]'),
    ),
  }));
  const authState = await detectFirebaseAuth(page);

  const failedRequests = relevantFailedRequests(diagnostics.failedRequests);
  const failures = [];
  if (!renderState.href.includes('/app')) {
    failures.push(`App did not return to /app. Final URL: ${renderState.href}`);
  }
  if (renderState.loadingExists) {
    failures.push('Loading overlay is still visible.');
  }
  if (!renderState.hasFlutterView) {
    failures.push('Flutter view is not rendered.');
  }
  if (authState.checked && !authState.signedIn) {
    failures.push('Firebase Auth still has no signed-in user after the manual step.');
  }
  if (diagnostics.consoleErrors.length > 0) {
    failures.push(`Console errors: ${diagnostics.consoleErrors.join(' | ')}`);
  }
  if (diagnostics.pageErrors.length > 0) {
    failures.push(`Page errors: ${diagnostics.pageErrors.join(' | ')}`);
  }
  if (failedRequests.length > 0) {
    failures.push(`Failed requests: ${JSON.stringify(failedRequests)}`);
  }
  if (diagnostics.badResponses.length > 0) {
    failures.push(`HTTP 4xx/5xx responses: ${JSON.stringify(diagnostics.badResponses)}`);
  }

  console.log('');
  console.log(`Final URL: ${renderState.href}`);
  console.log(`Firebase Auth signed in: ${authState.checked ? authState.signedIn : 'not checked'}`);
  if (authState.providerIds.length > 0) {
    console.log(`Auth providers: ${authState.providerIds.join(', ')}`);
  }
  console.log(`Screenshot: ${screenshotPath}`);

  await browser.close();

  if (failures.length > 0) {
    console.error('');
    console.error('Google auth manual smoke FAILED');
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exit(1);
  }

  console.log('Google auth manual smoke passed');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : error);
  process.exit(1);
});
