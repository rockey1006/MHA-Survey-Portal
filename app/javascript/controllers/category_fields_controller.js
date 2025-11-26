import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "item"]

  notifyChange() {
    window.dispatchEvent(new CustomEvent("survey:categories-changed"))
  }

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const uniqueId = Date.now().toString()
    const content = this.templateTarget.innerHTML.replace(/NEW_CATEGORY/g, uniqueId)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.notifyChange()
  }

  remove(event) {
    event.preventDefault()
    const wrapper = event.target.closest("[data-category-fields-target='item']")
    if (!wrapper) return

    const destroyCheckbox = wrapper.querySelector("input[type='checkbox'][name*='[_destroy]']")

    if (destroyCheckbox) {
      destroyCheckbox.checked = true
      wrapper.style.display = "none"
    } else {
      wrapper.remove()
    }

    this.notifyChange()
  }
}
