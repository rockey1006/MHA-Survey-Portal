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
    return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2, 10)}`
  }
}
