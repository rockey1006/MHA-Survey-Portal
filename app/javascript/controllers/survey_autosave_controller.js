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

    this.handleFormChange = this.handleFormChange.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleExternalChange = this.handleExternalChange.bind(this)

    this.element.addEventListener("input", this.handleFormChange)
    this.element.addEventListener("change", this.handleFormChange)
    this.element.addEventListener("submit", this.handleSubmit)
    window.addEventListener("survey:categories-changed", this.handleExternalChange)
    window.addEventListener("survey:sections-changed", this.handleExternalChange)
    window.addEventListener("survey:questions-changed", this.handleExternalChange)

    this.updateStatus("All changes saved", "idle")
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleFormChange)
    this.element.removeEventListener("change", this.handleFormChange)
    this.element.removeEventListener("submit", this.handleSubmit)
    window.removeEventListener("survey:categories-changed", this.handleExternalChange)
    window.removeEventListener("survey:sections-changed", this.handleExternalChange)
    window.removeEventListener("survey:questions-changed", this.handleExternalChange)
    this.clearPendingSave()
    this.abortPendingRequest()
  }

  handleFormChange() {
    if (this.isSubmitting) return
    this.queueSave()
  }

  handleExternalChange() {
    if (this.isSubmitting) return
    this.queueSave()
  }

  handleSubmit() {
    this.isSubmitting = true
    this.clearPendingSave()
  }

  queueSave() {
    this.updateStatus("Saving…", "saving")
    this.clearPendingSave()
    this.pendingTimeout = setTimeout(() => this.performSave(), this.debounceDuration)
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
      this.updateStatus(this.formatSavedMessage(this.lastSavedAt), "saved")
    } catch (error) {
      if (error.name === "AbortError") return
      this.updateStatus("Save failed. Retrying…", "error")
      this.pendingTimeout = setTimeout(() => this.performSave(), this.debounceDuration)
    } finally {
      this.isSaving = false
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
}
