import { Controller } from "@hotwired/stimulus"

// Automatically saves survey changes after a short idle delay.
export default class extends Controller {
  static targets = ["status"]
  static values = { debounce: Number }

  connect() {
    this.debounceDuration = this.hasDebounceValue ? this.debounceValue : 4000
    this.pendingTimeout = null
    this.isSaving = false
    this.isSubmitting = false
    this.lastSavedAt = null
    this.controller = null
    this.hasPendingChanges = false

    this.handleFormChange = this.handleFormChange.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleExternalChange = this.handleExternalChange.bind(this)
    this.handleBeforeUnload = this.handleBeforeUnload.bind(this)
    this.handleTurboBeforeVisit = this.handleTurboBeforeVisit.bind(this)
    this.handleTurboBeforeCache = this.handleTurboBeforeCache.bind(this)

    this.element.addEventListener("input", this.handleFormChange)
    this.element.addEventListener("change", this.handleFormChange)
    this.element.addEventListener("submit", this.handleSubmit)
    window.addEventListener("survey:categories-changed", this.handleExternalChange)
    window.addEventListener("survey:sections-changed", this.handleExternalChange)
    window.addEventListener("survey:questions-changed", this.handleExternalChange)
    window.addEventListener("beforeunload", this.handleBeforeUnload)
    document.addEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
    document.addEventListener("turbo:before-cache", this.handleTurboBeforeCache)

    this.updateStatus("All changes saved", "idle")
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleFormChange)
    this.element.removeEventListener("change", this.handleFormChange)
    this.element.removeEventListener("submit", this.handleSubmit)
    window.removeEventListener("survey:categories-changed", this.handleExternalChange)
    window.removeEventListener("survey:sections-changed", this.handleExternalChange)
    window.removeEventListener("survey:questions-changed", this.handleExternalChange)
    window.removeEventListener("beforeunload", this.handleBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
    document.removeEventListener("turbo:before-cache", this.handleTurboBeforeCache)
    this.clearPendingSave()
    this.abortPendingRequest()
  }

  handleFormChange() {
    if (this.isSubmitting) return
    this.queueSave({ immediate: false })
  }

  handleExternalChange() {
    if (this.isSubmitting) return
    // Structural edits (add/remove/reorder) should persist quickly so admins
    // don't lose changes by navigating away before the debounce fires.
    this.queueSave({ immediate: true })
  }

  handleSubmit() {
    this.isSubmitting = true
    this.clearPendingSave()
  }

  queueSave({ immediate } = {}) {
    this.hasPendingChanges = true
    this.updateStatus("Saving…", "saving")
    this.clearPendingSave()

    const delay = immediate ? 0 : this.debounceDuration
    this.pendingTimeout = setTimeout(() => this.performSave(), delay)
  }

  clearPendingSave() {
    if (this.pendingTimeout) {
      clearTimeout(this.pendingTimeout)
      this.pendingTimeout = null
    }
  }

  async performSave() {
    if (this.isSaving || this.isSubmitting) return

    this.isSaving = true
    this.updateStatus("Saving…", "saving")
    this.abortPendingRequest()
    this.controller = new AbortController()

    const formData = new FormData(this.element)
    formData.append("autosave", "1")

    try {
      const response = await fetch(this.element.action, {
        method: this.formMethod(),
        body: formData,
        signal: this.controller.signal,
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "X-Requested-With": "XMLHttpRequest",
          Accept: "text/vnd.turbo-stream.html, text/html, application/json"
        },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error("Autosave failed")

      this.lastSavedAt = new Date()
      this.hasPendingChanges = false
      this.updateStatus(this.formatSavedMessage(this.lastSavedAt), "saved")
    } catch (error) {
      if (error.name === "AbortError") return
      this.updateStatus("Save failed. Retrying…", "error")
      this.pendingTimeout = setTimeout(() => this.performSave(), this.debounceDuration)
    } finally {
      this.isSaving = false
    }
  }

  handleBeforeUnload() {
    if (this.isSubmitting) return
    if (!this.hasPendingChanges) return

    // Best-effort flush of the latest form state. This mirrors Google Forms'
    // "always saved" expectation and prevents lost nested updates.
    try {
      if (navigator.sendBeacon) {
        const formData = new FormData(this.element)
        formData.append("autosave", "1")
        navigator.sendBeacon(this.element.action, formData)
      }
    } catch {
      // No-op; leaving the page should still work even if beacon fails.
    }
  }

  abortPendingRequest() {
    if (this.controller) {
      this.controller.abort()
      this.controller = null
    }
  }

  formMethod() {
    const method = (this.element.getAttribute("method") || "post").toLowerCase()
    return method === "get" ? "post" : method
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  updateStatus(message, state) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
    this.element.dataset.autosaveState = state
  }

  formatSavedMessage(timestamp) {
    try {
      return `Saved ${timestamp.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`
    } catch {
      return "Saved"
    }
  }

  async handleTurboBeforeVisit(event) {
    if (this.isSubmitting) return
    if (this.isSaving) return

    // Turbo navigation (clicking links/buttons) does not always trigger
    // beforeunload. Flush pending changes before leaving the builder.
    if (!this.hasPendingChanges) return

    const url = event?.detail?.url
    if (!url) return

    // Prevent Turbo from navigating until we persist changes.
    event.preventDefault()

    // Avoid infinite loops if Turbo.visit re-triggers this handler.
    if (this._resumeTurboVisit) return
    this._resumeTurboVisit = true

    // Cancel the debounce and save now.
    this.clearPendingSave()
    await this.performSave()

    try {
      if (window.Turbo && typeof window.Turbo.visit === "function") {
        window.Turbo.visit(url)
      } else {
        window.location.href = url
      }
    } finally {
      this._resumeTurboVisit = false
    }
  }

  handleTurboBeforeCache() {
    // Turbo caches pages; make sure any pending edits are flushed first.
    this.handleBeforeUnload()
  }
}
