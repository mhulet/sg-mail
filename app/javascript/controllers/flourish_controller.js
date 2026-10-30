import { Controller } from "@hotwired/stimulus"

// Une scène animée (shared/_flourish) se retire une fois jouée, pour ne pas revenir avec le cache de Turbo.
export default class extends Controller {
  connect() {
    this.remove = this.remove.bind(this)
    this.element.addEventListener("animationend", this.remove)
    this.timer = setTimeout(this.remove, 3000)
    document.addEventListener("turbo:before-cache", this.remove)
  }

  disconnect() {
    clearTimeout(this.timer)
    document.removeEventListener("turbo:before-cache", this.remove)
  }

  remove(event) {
    if (event?.type === "animationend" && event.target !== this.element) return
    this.element.remove()
  }
}
