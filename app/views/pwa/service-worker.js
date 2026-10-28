// SG Mail installé comme une app (PWA, cadrage §8). Les pages viennent toujours du réseau :
// hors connexion, on affiche une page d'attente plutôt que l'erreur du navigateur.
const CACHE = "sg-mail-v2"
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

// Notifications (Web Push) : le serveur envoie { title, body, url, tag, badge }.
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {}
  const shown = self.registration.showNotification(data.title || "SG Mail", {
    body: data.body, tag: data.tag, icon: "/icon.png", badge: "/icon.png", data: { url: data.url || "/" }
  })
  const badge = typeof data.badge === "number" && navigator.setAppBadge
    ? (data.badge > 0 ? navigator.setAppBadge(data.badge) : navigator.clearAppBadge())
    : Promise.resolve()
  event.waitUntil(Promise.all([ shown, badge.catch(() => {}) ]))
})

// Toucher la notification ouvre le fil : dans une fenêtre déjà ouverte de SG Mail si possible.
self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const url = new URL(event.notification.data?.url || "/", self.location.origin).href
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
      const open = windows.find((client) => client.url.startsWith(self.location.origin))
      return open ? open.focus().then((client) => client.navigate(url)) : self.clients.openWindow(url)
    })
  )
})
