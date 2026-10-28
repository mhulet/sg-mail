import { Controller } from "@hotwired/stimulus"

// Screener : « Accepté » ou « Bloqué » se pose comme un coup de tampon pendant l'envoi de la décision.
export default class extends Controller {
  static targets = [ "stamp" ]

  press(event) {
    if (!this.hasStampTarget) return
    this.stampTarget.textContent = event.currentTarget.dataset.stampLabel
    this.element.classList.toggle("blocked", event.currentTarget.dataset.stampLabel === "Bloqué")
    this.element.classList.add("stamped")
  }
}
