import { Controller } from "@hotwired/stimulus"

// Un bouton qui déplie ou replie un bloc : sur téléphone, les filtres d'une liste restent rangés derrière « Filtrer ».
export default class extends Controller {
  static targets = [ "button" ]

  toggle() {
    const open = this.element.classList.toggle("open")
    this.buttonTarget.setAttribute("aria-expanded", open)
  }
}
