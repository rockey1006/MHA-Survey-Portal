import { Controller } from "@hotwired/stimulus"

// Collapses and expands the admin survey filters panel
export default class extends Controller {
  static targets = ["panel", "trigger"]
  static values = {
    defaultOpen: Boolean,
    active: Boolean
  }

  connect() {
    this.open = this.defaultOpenValue || false
    this.sync()
  }

  toggle() {
    this.open = !this.open
    this.sync()
  }

  sync() {
    if (this.hasPanelTarget) {
      if (this.open) {
        this.panelTarget.removeAttribute("hidden")
      } else {
        this.panelTarget.setAttribute("hidden", "hidden")
      }
    }

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(this.open))

      const hasActiveFilters = this.hasActiveValue ? this.activeValue : false
      const highlightBorder = this.open || (hasActiveFilters && !this.open)

      this.triggerTarget.classList.toggle("border-blue-500", highlightBorder)
      this.triggerTarget.classList.toggle("bg-blue-50", this.open)
      this.triggerTarget.classList.toggle("text-blue-600", this.open)
      this.triggerTarget.classList.toggle("ring-2", this.open)
      this.triggerTarget.classList.toggle("ring-blue-200", this.open)
      this.triggerTarget.classList.toggle("shadow-md", this.open)
    }
  }
}
