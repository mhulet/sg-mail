import { Controller } from "@hotwired/stimulus"

// Passkeys (WebAuthn) : ajouter une passkey depuis cet appareil, ou se connecter avec.
// Le serveur donne les options (base64url), le navigateur parle à l'appareil, le serveur vérifie.
export default class extends Controller {
  static values = { optionsUrl: String, url: String }
  static targets = [ "error" ]

  connect() {
    if (!window.PublicKeyCredential) this.element.hidden = true
  }

  async register(event) {
    event.preventDefault()
    await this.#run(async (options) => {
      options.challenge = decode(options.challenge)
      options.user.id = decode(options.user.id)
      options.excludeCredentials = (options.excludeCredentials || []).map((c) => ({ ...c, id: decode(c.id) }))
      const credential = await navigator.credentials.create({ publicKey: options })
      return {
        type: credential.type, id: credential.id, rawId: encode(credential.rawId),
        authenticatorAttachment: credential.authenticatorAttachment,
        clientExtensionResults: credential.getClientExtensionResults(),
        response: {
          clientDataJSON: encode(credential.response.clientDataJSON),
          attestationObject: encode(credential.response.attestationObject),
          transports: credential.response.getTransports ? credential.response.getTransports() : []
        }
      }
    })
  }

  async signIn(event) {
    event.preventDefault()
    await this.#run(async (options) => {
      options.challenge = decode(options.challenge)
      options.allowCredentials = (options.allowCredentials || []).map((c) => ({ ...c, id: decode(c.id) }))
      const credential = await navigator.credentials.get({ publicKey: options })
      return {
        type: credential.type, id: credential.id, rawId: encode(credential.rawId),
        authenticatorAttachment: credential.authenticatorAttachment,
        clientExtensionResults: credential.getClientExtensionResults(),
        response: {
          clientDataJSON: encode(credential.response.clientDataJSON),
          authenticatorData: encode(credential.response.authenticatorData),
          signature: encode(credential.response.signature),
          userHandle: credential.response.userHandle ? encode(credential.response.userHandle) : null
        }
      }
    })
  }

  async #run(ceremony) {
    this.#showError("")
    try {
      const options = await this.#post(this.optionsUrlValue)
      const credential = await ceremony(options)
      const result = await this.#post(this.urlValue, { credential })
      if (result.error) return this.#showError(result.error)
      window.Turbo ? Turbo.visit(result.redirect) : (window.location = result.redirect)
    } catch (error) {
      if (error.name !== "NotAllowedError" && error.name !== "AbortError") this.#showError("La passkey n'a pas pu être utilisée.")
    }
  }

  async #post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify(body)
    })
    return response.json()
  }

  #showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.hidden = !message
    }
  }
}

function decode(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(base64url.length / 4) * 4, "=")
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)).buffer
}

function encode(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}
