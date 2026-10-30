import { Controller } from "@hotwired/stimulus"

// L'iframe d'un email prend la hauteur de son contenu, et le bouton « ••• » déplie le texte cité.
// Aucun script ne tourne dans l'iframe : c'est la page qui mesure et qui déplie (même origine, voir la vue).
export default class extends Controller {
  static targets = [ "frame" ]

  disconnect() {
    this.observer?.disconnect()
  }

  fit() {
    const body = this.frameTarget.contentDocument?.body
    if (!body) return
    this.resize()
    // Les images arrivent après coup : la hauteur suit.
    this.observer?.disconnect()
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(body)
  }

  // On repart de zéro avant de mesurer : sinon la hauteur actuelle de l'iframe compte dans la mesure et elle ne rapetisse jamais.
  resize() {
    const root = this.frameTarget.contentDocument?.documentElement
    if (!root) return
    this.frameTarget.style.height = "0px"
    this.frameTarget.style.height = `${root.scrollHeight}px`
  }

  toggleQuote(event) {
    const root = this.frameTarget.contentDocument?.documentElement
    if (!root) return
    const open = root.classList.toggle("sg-show-quote")
    event.currentTarget.setAttribute("aria-expanded", open)
    event.currentTarget.title = open ? "Masquer le texte cité" : "Afficher le texte cité"
    this.resize()
  }
}
