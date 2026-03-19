import { Controller } from "@hotwired/stimulus"

// Controls ghost vs active states for question cards.
export default class extends Controller {
  static targets = ["expanded", "reparentPanel", "reparentToggle"]

  connect() {
    this.onActivate = this.onActivate.bind(this)
    window.addEventListener("survey-item:activate", this.onActivate)
    this.element.classList.remove("is-editing", "card-active")
    this.syncA11yState()
  }

  disconnect() {
    window.removeEventListener("survey-item:activate", this.onActivate)
  }

  expand() {
    window.dispatchEvent(new CustomEvent("survey-item:activate", { detail: { id: this.element.id } }))
  }

  onActivate(event) {
    const activeId = event?.detail?.id
    const active = !!activeId && activeId === this.element.id

    this.element.classList.toggle("is-editing", active)
    this.element.classList.toggle("card-active", active)

    if (!active && this.hasReparentPanelTarget) {
      this.reparentPanelTarget.classList.add("hidden")
      this.reparentToggleTarget?.setAttribute("aria-expanded", "false")
    }

    this.syncA11yState()
  }

  toggleReparent(event) {
    event?.preventDefault()
    this.expand()

    if (!this.hasReparentPanelTarget) return
    this.reparentPanelTarget.classList.toggle("hidden")
    this.reparentToggleTarget?.setAttribute(
      "aria-expanded",
      this.reparentPanelTarget.classList.contains("hidden") ? "false" : "true"
    )
  }

  syncA11yState() {
    if (!this.hasExpandedTarget) return
    this.expandedTarget.setAttribute("aria-hidden", this.element.classList.contains("is-editing") ? "false" : "true")
  }
}