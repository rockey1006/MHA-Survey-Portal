import { Controller } from "@hotwired/stimulus"

// Handles adding/removing nested question fields within the admin survey form.
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const uniqueId = Date.now().toString()
    const html = this.templateTarget.innerHTML.replace(/NEW_QUESTION/g, uniqueId)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
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
  }
}
