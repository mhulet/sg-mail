import { Controller } from "@hotwired/stimulus"

// Activer les notifications (Web Push) sur cet appareil. Sur iPhone, l'API n'existe que dans l'app ajoutée
// à l'écran d'accueil : ailleurs, on explique comment l'installer.
export default class extends Controller {
  static values = { key: String, url: String }
  static targets = [ "enable", "enabled", "denied", "install", "error" ]

  async connect() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
      return this.#show("install")
    }
    if (Notification.permission === "denied") return this.#show("denied")

    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.getSubscription()
    this.#show(subscription && Notification.permission === "granted" ? "enabled" : "enable")
  }

  async subscribe(event) {
    event.preventDefault()
    this.errorTarget.hidden = true
    try {
      // Doit venir directement du geste : Safari refuse la demande sinon.
      const permission = await Notification.requestPermission()
      if (permission !== "granted") return this.#show(permission === "denied" ? "denied" : "enable")

      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decode(this.keyValue) })
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
        body: JSON.stringify({ subscription: subscription.toJSON() })
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error)
      window.Turbo ? Turbo.visit(result.redirect) : (window.location = result.redirect)
    } catch (error) {
      this.errorTarget.textContent = error.message || "Impossible d'activer les notifications."
      this.errorTarget.hidden = false
    }
  }

  #show(name) {
    for (const target of [ "enable", "enabled", "denied", "install" ]) this[`${target}Target`].hidden = target !== name
  }
}

function decode(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(base64url.length / 4) * 4, "=")
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
}
