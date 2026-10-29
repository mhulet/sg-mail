import { Controller } from "@hotwired/stimulus"

// Installer SG Mail en un clic. Chrome, Edge et Brave proposent l'installation (beforeinstallprompt, gardé dans
// window.sgInstallPrompt par application.js, car il arrive souvent avant cette page) ; Safari et Firefox non :
// on montre alors les étapes du navigateur utilisé.
export default class extends Controller {
  static targets = [ "ready", "installed", "manual", "guide" ]

  connect() {
    this.refresh = this.refresh.bind(this)
    window.addEventListener("sg:installable", this.refresh)
    window.addEventListener("appinstalled", this.refresh)
    this.refresh()
  }

  disconnect() {
    window.removeEventListener("sg:installable", this.refresh)
    window.removeEventListener("appinstalled", this.refresh)
  }

  async install(event) {
    event.preventDefault()
    const prompt = window.sgInstallPrompt
    if (!prompt) return this.refresh()
    prompt.prompt()
    await prompt.userChoice.catch(() => {})
    window.sgInstallPrompt = null
    this.refresh()
  }

  refresh() {
    const installed = window.matchMedia("(display-mode: standalone)").matches || navigator.standalone || window.sgInstalled
    const state = installed ? "installed" : window.sgInstallPrompt ? "ready" : "manual"
    for (const target of [ "ready", "installed", "manual" ]) this[`${target}Target`].hidden = target !== state

    // Ouvre d'abord les étapes du navigateur utilisé.
    const browser = detectBrowser()
    for (const guide of this.guideTargets) guide.open = guide.dataset.browser === browser
  }
}

function detectBrowser() {
  const agent = navigator.userAgent
  if (/iPhone|iPad|iPod/.test(agent) || (/Macintosh/.test(agent) && navigator.maxTouchPoints > 1)) return "ios"
  if (/Firefox\//.test(agent)) return "firefox"
  if (/Safari\//.test(agent) && !/Chrome\/|Chromium\/|Edg\//.test(agent)) return "safari"
  if (/Android/.test(agent)) return "android"
  return "chromium"
}
