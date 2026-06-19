const STATIC_CACHE = 'goldtaxi-static-v2';
const STATIC_ASSET_EXTENSIONS = [
  '.js',
  '.css',
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.svg',
  '.webp',
  '.ico',
  '.woff',
  '.woff2',
  '.ttf',
  '.json',
];

const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/offline.html',
  '/manifest.json',
  '/apple-touch-icon.png',
  '/favicon-32x32.png',
  '/favicon-16x16.png',
  '/favicon.ico',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

const BLOCKED_CACHE_PATTERNS = [
  'firebase',
  'firestore',
  'identitytoolkit',
  'securetoken',
  'googleapis',
  'supabase',
  '/api/',
  'auth',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_URLS)),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== STATIC_CACHE)
          .map((key) => caches.delete(key)),
      ),
    ).then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (request.method !== 'GET') {
    return;
  }

  if (shouldBypassCache(url)) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(handleNavigation(request));
    return;
  }

  if (shouldCacheStaticAsset(url)) {
    event.respondWith(handleStaticAsset(request));
  }
});

function shouldBypassCache(url) {
  if (url.origin !== self.location.origin) {
    return true;
  }

  const lower = url.href.toLowerCase();
  return BLOCKED_CACHE_PATTERNS.some((pattern) => lower.includes(pattern));
}

function shouldCacheStaticAsset(url) {
  if (url.origin !== self.location.origin) {
    return false;
  }

  return STATIC_ASSET_EXTENSIONS.some((extension) =>
    url.pathname.endsWith(extension),
  );
}

async function handleNavigation(request) {
  try {
    return await fetch(request);
  } catch (error) {
    const cache = await caches.open(STATIC_CACHE);
    return (
      (await cache.match('/offline.html')) ||
      new Response('Offline', {
        status: 503,
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      })
    );
  }
}

async function handleStaticAsset(request) {
  const cache = await caches.open(STATIC_CACHE);
  const cached = await cache.match(request);

  if (cached) {
    eventSafeRevalidate(cache, request);
    return cached;
  }

  const response = await fetch(request);
  if (response && response.ok) {
    cache.put(request, response.clone());
  }
  return response;
}

async function eventSafeRevalidate(cache, request) {
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      await cache.put(request, response.clone());
    }
  } catch (_) {}
}
