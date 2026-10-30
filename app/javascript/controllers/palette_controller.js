import { Controller } from "@hotwired/stimulus"

// La palette ⌘K (Ctrl+K), à la Superhuman : un seul champ pour tout faire au clavier.
// Elle rassemble ce que la page sait déjà faire (les liens du menu, les boutons qui ont un raccourci,
// les entrées « en plus » de la palette), cherche les fils pendant la frappe (l'aperçu de la recherche)
// et propose toujours « Rechercher » en dernier. Flèches pour choisir, Entrée pour lancer, Échap pour fermer.
export default class extends Controller {
  static targets = [ "dialog", "input", "list", "extra" ]
  static values = { searchUrl: String, delay: { type: Number, default: 180 } }

  connect() {
    this.keydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    clearTimeout(this.timer)
  }

  keydown(event) {
    if ((event.metaKey || event.ctrlKey) && !event.altKey && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.dialogTarget.open ? this.close() : this.open()
    }
  }

  open() {
    this.commands = this.#collect()
    this.threads = []
    this.inputTarget.value = ""
    this.dialogTarget.showModal()
    this.inputTarget.focus()
    this.#render()
  }

  close() {
    clearTimeout(this.timer)
    this.abort?.abort()
    this.dialogTarget.close()
  }

  // Un clic sur le fond ferme la palette.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  type() {
    this.#render()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#searchThreads(), this.delayValue)
  }

  navigate(event) {
    const items = this.#items
    if (event.key === "ArrowDown" || event.key === "ArrowUp" || (event.ctrlKey && (event.key === "n" || event.key === "p"))) {
      event.preventDefault()
      const step = event.key === "ArrowDown" || event.key === "n" ? 1 : -1
      this.#select((this.selected + step + items.length) % items.length)
    } else if (event.key === "Enter") {
      event.preventDefault()
      items[this.selected]?.click()
    }
  }

  hover(event) {
    const index = this.#items.indexOf(event.target.closest("[role=option]"))
    if (index >= 0) this.#select(index, false)
  }

  run(event) {
    event.preventDefault()
    const option = event.target.closest("[role=option]")
    if (!option) return
    const command = this.shown[Number(option.dataset.index)]
    this.close()
    if (command.element?.isConnected) command.element.click()
    else if (command.href) Turbo.visit(command.href)
  }

  get #items() {
    return [ ...this.listTarget.querySelectorAll("[role=option]") ]
  }

  // Ce que la page sait faire, sans doublons : les boutons à raccourci visibles d'abord (actions du fil),
  // puis les liens du menu et les entrées en plus de la palette.
  #collect() {
    const seen = new Set()
    const commands = []
    const add = (element, group) => {
      const label = (element.dataset.paletteLabel || element.textContent || element.title || "").replace(/\s+/g, " ").trim()
      const href = element.getAttribute("href")
      const key = href ? `href:${href}` : `label:${label}`
      if (!label || seen.has(key) || seen.has(`label:${label}`)) return
      seen.add(key)
      seen.add(`label:${label}`)
      commands.push({ label, group, element, href, shortcut: element.dataset.shortcut?.split(",")[0].trim() })
    }

    document.querySelectorAll("main [data-shortcut], .toast [data-shortcut]").forEach((element) => {
      if (element.offsetParent !== null && !element.matches("input, textarea, select")) add(element, "Ici")
    })
    document.querySelectorAll(".sidebar nav.spaces a, .sidebar .compose-button").forEach((element) => add(element, "Aller à"))
    this.extraTargets.forEach((element) => add(element, "Aller à"))
    document.querySelectorAll(".sidebar .account-switcher a").forEach((element) => add(element, "Client"))
    document.querySelectorAll(".sidebar .settings a").forEach((element) => add(element, "Réglages"))
    return commands
  }

  #render() {
    const query = this.#normalize(this.inputTarget.value.trim())
    const words = query.split(/\s+/).filter(Boolean)
    const matches = this.commands
      .map((command) => ({ command, score: this.#score(this.#normalize(command.label), words) }))
      .filter(({ score }) => score > 0)
      .sort((a, b) => b.score - a.score)
      .map(({ command }) => command)
      .slice(0, words.length ? 8 : 40)

    this.shown = [ ...matches, ...this.threads ]
    if (query) this.shown.push({ label: `Rechercher « ${this.inputTarget.value.trim()} »`, group: "Rechercher", href: this.#searchHref() })

    this.listTarget.replaceChildren(...this.#groups())
    this.#select(0)
  }

  #groups() {
    const nodes = []
    let group = null
    this.shown.forEach((command, index) => {
      if (command.group !== group) {
        group = command.group
        const heading = document.createElement("li")
        heading.className = "palette-group"
        heading.setAttribute("role", "presentation")
        heading.textContent = group
        nodes.push(heading)
      }
      const option = document.createElement("li")
      option.setAttribute("role", "option")
      option.id = `palette-option-${index}`
      option.dataset.index = index
      const label = document.createElement("span")
      label.className = "palette-label"
      label.textContent = command.label
      option.append(label)
      if (command.detail) {
        const detail = document.createElement("span")
        detail.className = "palette-detail"
        detail.textContent = command.detail
        option.append(detail)
      }
      if (command.shortcut) {
        const kbd = document.createElement("kbd")
        kbd.textContent = command.shortcut
        option.append(kbd)
      }
      nodes.push(option)
    })
    if (!nodes.length) {
      const empty = document.createElement("li")
      empty.className = "palette-empty"
      empty.textContent = "Rien à proposer."
      nodes.push(empty)
    }
    return nodes
  }

  #select(index, scroll = true) {
    const items = this.#items
    this.selected = Math.max(0, Math.min(index, items.length - 1))
    items.forEach((item, i) => item.setAttribute("aria-selected", i === this.selected))
    const current = items[this.selected]
    this.inputTarget.setAttribute("aria-activedescendant", current?.id || "")
    if (scroll) current?.scrollIntoView({ block: "nearest" })
  }

  // Tous les mots doivent être présents ; un libellé qui commence par la recherche passe devant.
  #score(label, words) {
    if (!words.length) return 1
    if (!words.every((word) => label.includes(word))) return 0
    return (label.startsWith(words.join(" ")) ? 3 : 0) + (words.some((word) => label.split(/\s+/).some((part) => part.startsWith(word))) ? 2 : 1)
  }

  #normalize(text) {
    return text.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  }

  #searchHref() {
    const url = new URL(this.searchUrlValue, window.location.href)
    url.searchParams.set("q", this.inputTarget.value.trim())
    return url.toString()
  }

  // Les fils trouvés : l'aperçu de la recherche du menu, demandé comme le ferait son cadre.
  async #searchThreads() {
    const query = this.inputTarget.value.trim()
    this.abort?.abort()
    if (query.length < 2 || !this.hasSearchUrlValue) {
      if (this.threads.length) { this.threads = []; this.#render() }
      return
    }
    this.abort = new AbortController()
    try {
      const response = await fetch(this.#searchHref(), {
        headers: { "Turbo-Frame": "search_preview", Accept: "text/html" }, signal: this.abort.signal
      })
      if (!response.ok) return
      const html = new DOMParser().parseFromString(await response.text(), "text/html")
      this.threads = [ ...html.querySelectorAll(".search-preview a.result") ].map((link) => ({
        label: link.querySelector(".subject")?.textContent.trim() || "(sans objet)",
        detail: link.querySelector(".sender")?.textContent.trim(),
        group: "Fils",
        href: link.getAttribute("href")
      }))
      if (this.inputTarget.value.trim() === query) this.#render()
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }
}
