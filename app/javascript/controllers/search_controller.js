import { Controller } from "@hotwired/stimulus"

// Résultats pendant la frappe. Sur la page de recherche, le formulaire vise le cadre des résultats :
// on le soumet. Dans le menu, on charge un aperçu sous le champ (cible « preview ») ; Entrée ouvre
// toujours la page complète. Flèches haut et bas pour parcourir l'aperçu, Échap pour le fermer.
export default class extends Controller {
  static targets = [ "input", "preview" ]
  static values = { delay: { type: Number, default: 200 } }

  connect() {
    // Le champ garde le focus après un rechargement de la page : on place le curseur à la fin.
    const input = this.inputTarget
    if (document.activeElement === input) input.setSelectionRange(input.value.length, input.value.length)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  type() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#search(), this.delayValue)
  }

  keydown(event) {
    if (!this.hasPreviewTarget) return
    const links = [ ...this.previewTarget.querySelectorAll("a") ]
    const index = links.indexOf(document.activeElement)
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (!links.length) return
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      const next = index + step
      if (next < 0) return this.inputTarget.focus()
      links[Math.min(next, links.length - 1)].focus()
    } else if (event.key === "Escape") {
      this.close()
      this.inputTarget.blur()
    }
  }

  // L'aperçu se ferme quand le focus quitte le champ et ses résultats.
  leave(event) {
    if (!this.element.contains(event.relatedTarget)) this.close()
  }

  close() {
    if (!this.hasPreviewTarget) return
    clearTimeout(this.timer)
    this.previewTarget.removeAttribute("src")
    this.previewTarget.innerHTML = ""
  }

  #search() {
    if (!this.hasPreviewTarget) return this.element.requestSubmit()

    const query = this.inputTarget.value.trim()
    if (!query) return this.close()
    const url = new URL(this.element.action, window.location.href)
    url.searchParams.set("q", query)
    const field = this.inputTarget.getBoundingClientRect()
    this.previewTarget.style.setProperty("--left", `${field.left}px`)
    this.previewTarget.style.setProperty("--top", `${field.bottom + 6}px`)
    this.previewTarget.src = url.toString()
  }
}
