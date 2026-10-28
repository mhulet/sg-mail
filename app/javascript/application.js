// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// SG Mail installable comme une app (PWA).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch(() => {})
}

// La pastille de l'icône (app installée) suit les non-lus de la réception à chaque page.
document.addEventListener("turbo:load", () => {
  const count = Number(document.body.dataset.badge)
  if (!navigator.setAppBadge || Number.isNaN(count) || document.body.dataset.badge === undefined) return
  ;(count > 0 ? navigator.setAppBadge(count) : navigator.clearAppBadge()).catch(() => {})
})
