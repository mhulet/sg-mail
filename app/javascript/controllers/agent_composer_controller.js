import { Controller } from "@hotwired/stimulus"

// Écrire à l'agent : Entrée envoie, Maj + Entrée va à la ligne.
export default class extends Controller {
  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (event.target.value.trim()) this.element.requestSubmit()
  }
}
