// Duck's service worker. Keeps the page and its files so it opens with no signal.
// Bump CACHE whenever any file below changes, or people keep seeing the old page.
const CACHE = 'duck-v7';
const FILES = [
  '/',
  '/index.html',
  '/css/duck.css?v=4',
  '/fonts/exposure-30.otf',
  '/fonts/inter.woff2',
  '/images/favicon.svg?v=4',
  '/images/icon-192.png?v=3',
  '/images/icon-512.png?v=3',
  '/site.webmanifest?v=3',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

// Network first, cache as the fallback: a fresh page when there is signal, the last one when there is not.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== location.origin) return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request).then((hit) => hit || caches.match('/')))
  );
});
