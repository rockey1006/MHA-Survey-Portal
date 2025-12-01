import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "item", "sectionSelect"]

  notifyChange() {
    window.dispatchEvent(new CustomEvent("survey:categories-changed"))
  }

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasContainerTarget) return

    const uniqueId = Date.now().toString()
    const content = this.templateTarget.innerHTML.replace(/NEW_CATEGORY/g, uniqueId)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    this.refreshNewSectionSelects()
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

  connect() {
    this.handleSectionsChanged = this.refreshSectionOptions.bind(this)
    window.addEventListener("survey:sections-changed", this.handleSectionsChanged)
    if (!this.currentSectionOptions && this.sectionSelectTargets.length > 0) {
      this.currentSectionOptions = this.extractOptionsFromSelect(this.sectionSelectTargets[0])
    }
  }

  disconnect() {
    window.removeEventListener("survey:sections-changed", this.handleSectionsChanged)
  }

  refreshSectionOptions(event) {
    const sections = Array.isArray(event?.detail?.sections) ? event.detail.sections : []
    this.currentSectionOptions = [
      { uid: "", label: "No section" },
      ...sections.map((section) => ({
        uid: section?.uid || "",
        label: section?.label?.trim()?.length ? section.label.trim() : "Untitled section"
      }))
    ]
    this.sectionSelectTargets.forEach((select) => this.populateSectionSelect(select))
  }

  refreshNewSectionSelects() {
    if (!this.currentSectionOptions) return
    this.sectionSelectTargets.forEach((select) => this.populateSectionSelect(select))
  }

  populateSectionSelect(select) {
    if (!this.currentSectionOptions) return
    const previousValue = select.value
    select.innerHTML = ""
    this.currentSectionOptions.forEach((option) => {
      const element = document.createElement("option")
      element.value = option.uid
      element.textContent = option.label
      select.appendChild(element)
    })
    const hasPrevious = this.currentSectionOptions.some((option) => option.uid === previousValue)
    select.value = hasPrevious ? previousValue : ""
  }

  extractOptionsFromSelect(select) {
    if (!select) return null
    return Array.from(select.options).map((option) => ({ uid: option.value, label: option.textContent || option.value }))
  }
}
