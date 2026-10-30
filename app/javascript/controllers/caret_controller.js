import { Controller } from "@hotwired/stimulus"

// Une réponse s'écrit au-dessus de la signature et de la citation : le curseur se place tout au début du champ.
export default class extends Controller {
  connect() {
    this.element.setSelectionRange(0, 0)
    this.element.scrollTop = 0
  }
}
