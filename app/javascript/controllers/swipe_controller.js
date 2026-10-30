import { Controller } from "@hotwired/stimulus"

// Glisser une ligne du doigt, comme dans Gmail ou Spark : vers la gauche, on archive ; vers la droite, « Répondre plus tard ».
// Sous la ligne apparaît la couleur de l'action ; passé le seuil, elle s'affirme, et au lâcher la ligne file
// puis l'action part (la page suivante joue la petite scène). En deçà du seuil, la ligne revient à sa place.
// Seulement au doigt : à la souris, la ligne reste un lien.
export default class extends Controller {
  static values = { archiveUrl: String, laterUrl: String }

  connect() {
    this.start = this.start.bind(this)
    this.element.addEventListener("touchstart", this.start, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.start)
    this.#cleanup()
  }

  start(event) {
    if (event.touches.length !== 1 || this.busy) return
    const touch = event.touches[0]
    this.x0 = touch.clientX
    this.y0 = touch.clientY
    this.dx = 0
    this.mode = null // null tant qu'on ne sait pas si le doigt défile ou glisse
    this.move = this.move.bind(this)
    this.end = this.end.bind(this)
    this.element.addEventListener("touchmove", this.move, { passive: false })
    this.element.addEventListener("touchend", this.end)
    this.element.addEventListener("touchcancel", this.end)
  }

  move(event) {
    const touch = event.touches[0]
    const dx = touch.clientX - this.x0
    const dy = touch.clientY - this.y0

    if (this.mode === null) {
      if (Math.abs(dx) < 8 && Math.abs(dy) < 8) return
      this.mode = Math.abs(dx) > Math.abs(dy) * 1.2 ? "swipe" : "scroll"
      if (this.mode === "swipe") this.#begin()
    }
    if (this.mode !== "swipe") return

    event.preventDefault()
    this.dx = this.#clamp(dx)
    this.element.style.transform = `translateX(${this.dx}px)`
    this.#paint()
  }

  end() {
    this.element.removeEventListener("touchmove", this.move)
    this.element.removeEventListener("touchend", this.end)
    this.element.removeEventListener("touchcancel", this.end)
    if (this.mode !== "swipe") return

    // Un glissé n'est pas un toucher : la ligne ne s'ouvre pas au lâcher.
    const preventClick = (event) => event.preventDefault()
    this.element.addEventListener("click", preventClick, { capture: true, once: true })
    setTimeout(() => this.element.removeEventListener("click", preventClick, { capture: true }), 400)

    const action = this.#armed
    if (!action) return this.#settle()

    this.busy = true
    this.element.classList.add("swiped")
    this.element.style.transform = `translateX(${Math.sign(this.dx) * this.element.offsetWidth}px)`
    setTimeout(() => this.#submit(action), 180)
  }

  get #width() {
    return this.element.offsetWidth || 1
  }

  get #threshold() {
    return Math.min(140, this.#width * 0.35)
  }

  // L'action qui partira au lâcher, ou null.
  get #armed() {
    if (Math.abs(this.dx) < this.#threshold) return null
    return this.dx < 0 ? "archive" : "later"
  }

  // On ne glisse que dans le sens d'une action possible.
  #clamp(dx) {
    if (dx < 0 && !this.hasArchiveUrlValue) return 0
    if (dx > 0 && !this.hasLaterUrlValue) return 0
    return dx
  }

  #begin() {
    this.reveal = document.createElement("div")
    this.reveal.className = "swipe-reveal"
    this.reveal.setAttribute("aria-hidden", "true")
    this.reveal.innerHTML = `<span class="later">Plus tard</span><span class="archive">Archiver</span>`
    this.reveal.style.top = `${this.element.offsetTop}px`
    this.reveal.style.height = `${this.element.offsetHeight}px`
    this.element.parentElement.append(this.reveal)
    this.element.classList.add("swiping")
  }

  #paint() {
    const side = this.dx < 0 ? "archive" : this.dx > 0 ? "later" : ""
    const armed = this.#armed
    this.reveal.dataset.side = side
    this.reveal.classList.toggle("armed", !!armed)
    if (armed !== this.lastArmed) {
      if (armed) navigator.vibrate?.(8)
      this.lastArmed = armed
    }
  }

  #settle() {
    this.element.classList.add("settling")
    this.element.style.transform = ""
    setTimeout(() => this.#cleanup(), 300)
  }

  #cleanup() {
    this.element.classList.remove("swiping", "settling")
    this.reveal?.remove()
    this.reveal = null
    this.lastArmed = null
  }

  // Un formulaire envoyé par Turbo, comme les boutons de la page du fil.
  #submit(action) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = action === "archive" ? this.archiveUrlValue : this.laterUrlValue
    form.hidden = true
    const fields = { _method: "patch", authenticity_token: document.querySelector("meta[name=csrf-token]")?.content, on: "1" }
    if (action === "later") fields.stack = "reply_later"
    Object.entries(fields).forEach(([ name, value ]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value ?? ""
      form.append(input)
    })
    document.body.append(form)
    form.requestSubmit()
  }
}
