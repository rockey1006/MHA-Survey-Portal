import { Controller } from "@hotwired/stimulus"

// Handles adding/removing nested question fields within the admin survey form.
export default class extends Controller {
  static targets = ["container", "template"]

  notifyChange() {
    window.dispatchEvent(new CustomEvent("survey:questions-changed"))
  }

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const uniqueId = this.uniqueToken()
    const html = this.templateTarget.innerHTML.replace(/NEW_QUESTION/g, uniqueId)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
    this.notifyChange()
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest('[data-question-fields-target="item"]')
    if (!item) return

    const destroyInput = item.querySelector('input[name$="[_destroy]"]')
    if (destroyInput) {
      destroyInput.value = "1"
    }

    item.style.display = "none"
    this.notifyChange()
  }

  uniqueToken() {
    // Must be digits-only so Rails strong params keeps nested attributes.
    return `${Date.now()}${Math.floor(Math.random() * 1_000_000_000)}`
  }
}
