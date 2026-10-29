import { Controller } from "@hotwired/stimulus"

// Raccourcis clavier, à la Gmail. Un élément les déclare avec data-shortcut="e" (ou "g i" pour une suite) :
// une touche clique le lien ou le bouton, ou donne le focus au champ. Dans une liste, j et k déplacent
// la ligne courante, o ou Entrée l'ouvrent, x la coche ; une action groupée vise la ligne courante si rien
// n'est coché. ? affiche l'aide. Rien ne se passe pendant la saisie dans un champ.
export default class extends Controller {
  static targets = [ "row", "link", "help" ]

  connect() {
    this.index = -1
    this.prefix = null
    this.keydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
  }

  keydown(event) {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || this.#typing(event.target)) return

    const key = this.prefix ? `${this.prefix} ${event.key}` : event.key
    this.prefix = null
    clearTimeout(this.prefixTimer)

    if (key === "g") {
      this.prefix = "g"
      this.prefixTimer = setTimeout(() => (this.prefix = null), 1500)
      return event.preventDefault()
    }
    if (key === "?" && this.hasHelpTarget) return this.#handled(event, () => this.helpTarget.showModal())
    if (key === "Escape" && document.activeElement?.matches("input[type=search]")) return document.activeElement.blur()
    if (key === "Escape" && document.querySelector("details[open]")) return document.querySelectorAll("details[open]").forEach((details) => (details.open = false))

    if (this.rowTargets.length) {
      if (key === "j") return this.#handled(event, () => this.#move(1))
      if (key === "k") return this.#handled(event, () => this.#move(-1))
      if ((key === "o" || key === "Enter") && this.#current) return this.#handled(event, () => this.#current.querySelector("[data-shortcuts-target~=link]").click())
      if (key === "x" && this.#current) return this.#handled(event, () => this.#toggle(this.#current))
    }

    const element = this.#elementFor(key)
    if (!element) return
    event.preventDefault()
    if (element.matches("input, textarea, select")) return element.focus()
    if (element.dataset.shortcutBulk !== undefined && !this.#anyChecked && this.#current) this.#toggle(this.#current, true)
    element.click()
  }

  // Archiver depuis une liste : les lignes visées glissent hors de la liste pendant l'envoi.
  leave(event) {
    if (event.submitter?.value !== "archive") return
    this.rowTargets
      .filter((row) => row.querySelector("input[type=checkbox]")?.checked)
      .forEach((row) => row.classList.add("leaving"))
  }

  get #current() {
    return this.rowTargets[this.index]
  }

  get #anyChecked() {
    return this.rowTargets.some((row) => row.querySelector("input[type=checkbox]")?.checked)
  }

  #move(step) {
    this.#current?.classList.remove("current")
    this.index = Math.max(0, Math.min(this.rowTargets.length - 1, this.index + step))
    this.#current.classList.add("current")
    this.#current.scrollIntoView({ block: "nearest" })
  }

  #toggle(row, value) {
    const checkbox = row.querySelector("input[type=checkbox]")
    if (checkbox) checkbox.checked = value ?? !checkbox.checked
  }

  #elementFor(key) {
    return [ ...document.querySelectorAll("[data-shortcut]") ]
      .find((element) => element.dataset.shortcut.split(",").map((s) => s.trim()).includes(key) && element.offsetParent !== null)
  }

  #typing(target) {
    return target.closest?.("input, textarea, select, [contenteditable]") && !target.matches("input[type=checkbox]")
  }

  #handled(event, action) {
    event.preventDefault()
    action()
  }
}
