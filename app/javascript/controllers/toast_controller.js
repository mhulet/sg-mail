import { Controller } from "@hotwired/stimulus"

// Le bandeau de confirmation (« Fil archivé », avec « Annuler ») s'efface tout seul après quelques secondes,
// sauf si la souris ou le focus s'y attardent.
export default class extends Controller {
  static values = { delay: { type: Number, default: 6000 } }

  connect() {
    this.schedule()
    this.element.addEventListener("mouseenter", () => clearTimeout(this.timer))
    this.element.addEventListener("mouseleave", () => this.schedule())
    this.element.addEventListener("focusin", () => clearTimeout(this.timer))
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.classList.add("gone"), this.delayValue)
  }
}
