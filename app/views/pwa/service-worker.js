// SG Mail installé comme une app (PWA, cadrage §8). Les pages viennent toujours du réseau :
// hors connexion, on affiche une page d'attente plutôt que l'erreur du navigateur.
const CACHE = "sg-mail-v1"
const OFFLINE_URL = "/offline.html"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll([ OFFLINE_URL, "/icon.png" ])))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return

  event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)))
})
