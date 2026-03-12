import { Controller } from "@hotwired/stimulus"

// Tab controller for switching between Settings and Builder views without page reload.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.activeTabId = "settings"
    this.sync()
  }

  switchTab(event) {
    event?.preventDefault()
    const nextId = (event?.currentTarget?.dataset?.tabId || "").trim()
    if (!nextId.length) return

    this.activeTabId = nextId
    this.sync()
  }

  sync() {
    this.tabTargets.forEach((tab) => {
      const tabId = tab.dataset.tabId
      const isActive = tabId === this.activeTabId

      tab.setAttribute("aria-selected", isActive ? "true" : "false")
      tab.classList.toggle("btn-primary", isActive)
      tab.classList.toggle("btn-secondary", !isActive)
    })

    this.panelTargets.forEach((panel) => {
      const panelId = panel.dataset.tabPanel
      const isActive = panelId === this.activeTabId
      panel.classList.toggle("hidden", !isActive)
      panel.setAttribute("aria-hidden", isActive ? "false" : "true")
    })
  }
}
