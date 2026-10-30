import { Controller } from "@hotwired/stimulus"

// Visionneuse des pièces jointes d'un fil : images et PDF s'ouvrent en plein écran sans quitter le fil.
// ← → passent de l'une à l'autre, d télécharge, Échap ferme ; sur téléphone, on glisse du doigt.
// Les autres fichiers gardent leur lien de téléchargement.
export default class extends Controller {
  static targets = [ "item", "dialog", "stage", "name", "count", "download", "prev", "next" ]

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey) return
    event.preventDefault()
    this.group = event.currentTarget.dataset.viewerGroup
    this.#show(this.#items.indexOf(event.currentTarget))
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  next() { this.#step(1) }
  previous() { this.#step(-1) }
  close() { this.dialogTarget.close() }

  // Ferme en cliquant à côté de la pièce jointe.
  backdrop(event) {
    if (event.target === this.dialogTarget || event.target === this.stageTarget) this.close()
  }

  closed() {
    this.stageTarget.replaceChildren()
  }

  // Les raccourcis du fil (e, r, u…) restent en sommeil tant que la visionneuse est ouverte.
  keydown(event) {
    if (event.key === "Escape") return
    event.stopPropagation()
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (event.key === "ArrowRight" || event.key === "j") this.#handled(event, () => this.next())
    else if (event.key === "ArrowLeft" || event.key === "k") this.#handled(event, () => this.previous())
    else if (event.key === "d") this.#handled(event, () => this.downloadTarget.click())
  }

  touchstart(event) {
    this.touchX = event.changedTouches[0].clientX
  }

  touchend(event) {
    const distance = event.changedTouches[0].clientX - this.touchX
    if (Math.abs(distance) > 60) this.#step(distance < 0 ? 1 : -1)
  }

  // Pas de vignette possible (type inconnu du serveur, fichier abîmé) : on garde l'icône.
  broken(event) {
    event.target.remove()
  }

  // Dans une liste de fils, on ne passe que d'une pièce jointe à l'autre du même fil (data-viewer-group).
  get #items() {
    return this.itemTargets.filter((item) => item.dataset.viewerKind && item.dataset.viewerGroup === this.group)
  }

  #step(offset) {
    const items = this.#items
    if (items.length < 2) return
    this.#show((this.index + offset + items.length) % items.length)
  }

  #show(index) {
    const item = this.#items[index]
    if (!item) return
    this.index = index

    const media = document.createElement(item.dataset.viewerKind === "pdf" ? "iframe" : "img")
    media.src = item.href
    if (media.tagName === "IMG") media.alt = item.dataset.viewerName
    else media.title = item.dataset.viewerName
    this.stageTarget.replaceChildren(media)
    this.stageTarget.dataset.kind = item.dataset.viewerKind

    this.nameTarget.textContent = item.dataset.viewerName
    this.downloadTarget.href = item.dataset.viewerDownload
    const count = this.#items.length
    this.countTarget.textContent = count > 1 ? `${index + 1} / ${count}` : ""
    this.prevTarget.hidden = this.nextTarget.hidden = count < 2
  }

  #handled(event, action) {
    event.preventDefault()
    action()
  }
}
