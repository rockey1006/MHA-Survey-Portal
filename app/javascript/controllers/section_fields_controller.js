import { Controller } from "@hotwired/stimulus"

// Manages nested section fields and keeps category section selectors in sync.
export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    this.handleTitleInput = this.handleTitleInput.bind(this)
    this.element.addEventListener("input", this.handleTitleInput)
    this.broadcastSections()
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleTitleInput)
  }

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const uniqueId = Date.now().toString()
    const formUid = this.generateFormUid()
    let html = this.templateTarget.innerHTML
    html = html.replace(/NEW_SECTION_UID/g, formUid)
    html = html.replace(/NEW_SECTION/g, uniqueId)

    this.containerTarget.insertAdjacentHTML("beforeend", html)
    this.broadcastSections()
  }

  remove(event) {
    event.preventDefault()
    const entry = event.target.closest("[data-section-entry]")
    if (!entry) return

    const destroyInput = entry.querySelector('input[name$="[_destroy]"]')
    const idInput = entry.querySelector('input[name$="[id]"]')

    if (idInput && idInput.value.trim() !== "") {
      if (destroyInput) destroyInput.value = "1"
      entry.classList.add("hidden")
    } else {
      entry.remove()
    }

    this.broadcastSections()
  }

  handleTitleInput(event) {
    if (event.target && event.target.matches('input[name$="[title]"]')) {
      this.broadcastSections()
    }
  }

  broadcastSections() {
    if (!this.hasContainerTarget) return

    const sections = Array.from(this.containerTarget.querySelectorAll("[data-section-entry]"))
      .map((entry) => {
        const destroyInput = entry.querySelector('input[name$="[_destroy]"]')
        if (destroyInput && destroyInput.value === "1") return null

        const uidInput = entry.querySelector('input[name$="[form_uid]"]')
        if (!uidInput || uidInput.value.trim() === "") return null

        const titleInput = entry.querySelector('input[name$="[title]"]')
        const label = titleInput && titleInput.value.trim().length > 0 ? titleInput.value.trim() : "Untitled section"
        return { uid: uidInput.value.trim(), label }
      })
      .filter(Boolean)

    const event = new CustomEvent("survey:sections-changed", {
      detail: { sections }
    })
    window.dispatchEvent(event)
  }

  generateFormUid() {
    return `section-temp-${Date.now().toString(16)}-${Math.random().toString(16).slice(2, 8)}`
  }
}
