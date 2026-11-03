const CACHE_NAME = 'app-cache-v6';

// Map old icon paths to new ones
const ICON_REDIRECTS = {
  '/icons/Icon-192.png': '/icons/icon-v3-192.png',
  '/icons/Icon-512.png': '/icons/icon-v3-512.png',
  '/icons/Icon-maskable-192.png': '/icons/icon-v3-192.png',
  '/icons/Icon-maskable-512.png': '/icons/icon-v3-512.png',
  '/icons/icon-v2-192.png': '/icons/icon-v3-192.png',
  '/icons/icon-v2-512.png': '/icons/icon-v3-512.png',
  '/icons/icon-v2-maskable-192.png': '/icons/icon-v3-192.png',
  '/icons/icon-v2-maskable-512.png': '/icons/icon-v3-512.png',
  '/favicon.png': '/icons/icon-v3-192.png',
  '/favicon.ico': '/icons/icon-v3-192.png',
  '/favicon-v2.png': '/icons/icon-v3-192.png',
  '/favicon-v2.ico': '/icons/icon-v3-192.png',
};

self.addEventListener('install', (event) => {
  // Force immediate activation — don't wait for old tabs to close
  self.skipWaiting();
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    // Delete ALL caches unconditionally
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          console.log('[SW] Deleting cache:', cacheName);
          return caches.delete(cacheName);
        })
      );
    }).then(() => {
      console.log('[SW] All caches cleared. Claiming clients.');
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Strip query params for matching (Android WebAPK ignores them anyway)
  const pathname = url.pathname;

  // If someone requests an old icon path, redirect to new one
  if (ICON_REDIRECTS[pathname]) {
    const newUrl = new URL(ICON_REDIRECTS[pathname], url.origin);
    // Add cache-buster to force fresh fetch
    newUrl.searchParams.set('_cb', Date.now());
    event.respondWith(
      fetch(newUrl.toString(), { cache: 'no-store' })
    );
    return;
  }

  // If requesting the old manifest.json, redirect to manifest-v2.json
  if (pathname === '/manifest.json') {
    const newUrl = new URL('/manifest-v2.json', url.origin);
    newUrl.searchParams.set('_cb', Date.now());
    event.respondWith(
      fetch(newUrl.toString(), { cache: 'no-store' })
    );
    return;
  }

  // For manifest-v2.json and icon files, always fetch from network (no cache)
  if (pathname === '/manifest-v2.json' || pathname.startsWith('/icons/')) {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' })
    );
    return;
  }

  // Everything else: network-first, bypassing stale HTTP cache for scripts/html/json
  const shouldBypassHttpCache =
    pathname === '/' ||
    pathname.endsWith('.js') ||
    pathname.endsWith('.html') ||
    pathname.endsWith('.json');
  event.respondWith(
    fetch(
      event.request,
      shouldBypassHttpCache ? { cache: 'no-cache' } : undefined
    ).catch(() => caches.match(event.request))
  );
});
