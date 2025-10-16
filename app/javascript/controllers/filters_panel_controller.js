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
      this.triggerTarget.classList.toggle("is-active", this.open)

      const hasActiveFilters = this.hasActiveValue ? this.activeValue : false
      this.triggerTarget.classList.toggle("has-active-filters", hasActiveFilters && !this.open)
    }

    this.element.classList.toggle("admin-surveys-header--filters-open", this.open)
  }
}
