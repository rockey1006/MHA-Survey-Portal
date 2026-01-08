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
    this.lastSaveSucceeded = true
    this.lastSaveWasValidationError = false
    this.lastValidationMessage = null
    this.saveQueuedDuringSave = false
    this.changeVersion = 0
    this.didRefreshAfterAutosave = false
    this.refreshQueued = false
    this.allowImmediateSubmit = false
    this.submitAfterReloadKey = `survey_autosave_submit_after_reload:${this.element.action}`

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

    this.resumeSubmitAfterReloadIfNeeded()
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

  async handleSubmit(event) {
    // Allow a single programmatic submit without re-entering our guard logic.
    if (this.allowImmediateSubmit) {
      this.allowImmediateSubmit = false
      this.isSubmitting = true
      this.clearPendingSave()
      return
    }

    if (this.isSubmitting) return

    // If there are unsynced nested records (blank ids), submitting the form
    // will re-create them (duplicates). Force a refresh so the server-rendered
    // form contains the persisted IDs.
    if (this.hasBlankNestedIds()) {
      event?.preventDefault?.()
      sessionStorage.setItem(this.submitAfterReloadKey, "1")
      window.location.reload()
      return
    }

    // If an autosave is in-flight or pending, flush it first so the submit
    // reflects the latest state and doesn't race two writes.
    if (this.isSaving || this.hasPendingChanges || this.pendingTimeout) {
      event?.preventDefault?.()
      this.clearPendingSave()
      await this.performSave()

      if (!this.lastSaveSucceeded || this.hasPendingChanges) {
        const suffix = this.lastValidationMessage ? ` — ${this.lastValidationMessage}` : ""
        this.updateStatus(`Cannot save${suffix}`, "error")
        return
      }

      if (this.hasBlankNestedIds()) {
        sessionStorage.setItem(this.submitAfterReloadKey, "1")
        window.location.reload()
        return
      }

      this.allowImmediateSubmit = true
      this.element.requestSubmit()
      return
    }

    this.isSubmitting = true
    this.clearPendingSave()
  }

  resumeSubmitAfterReloadIfNeeded() {
    try {
      const shouldSubmit = sessionStorage.getItem(this.submitAfterReloadKey) === "1"
      if (!shouldSubmit) return

      sessionStorage.removeItem(this.submitAfterReloadKey)

      // If the form still contains blank ids, we are not safe to submit yet.
      if (this.hasBlankNestedIds()) return

      this.allowImmediateSubmit = true
      setTimeout(() => this.element.requestSubmit(), 0)
    } catch {
      // Ignore storage errors.
    }
  }

  queueSave({ immediate } = {}) {
    this.hasPendingChanges = true
    this.changeVersion += 1
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
    if (this.isSubmitting) return

    // Avoid dropping updates that occur while a save is already in-flight.
    // If another change arrives during a save, queue a follow-up save.
    if (this.isSaving) {
      this.saveQueuedDuringSave = true
      return
    }

    const versionAtStart = this.changeVersion

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

      this.lastSaveWasValidationError = response.status === 422
      if (!response.ok) {
        this.lastSaveSucceeded = false
        // Validation errors won't succeed without user edits; don't spin.
        if (this.lastSaveWasValidationError) {
          const body = await response.text().catch(() => "")
          const validationMessage = this.extractFirstErrorMessage(body)
          this.lastValidationMessage = validationMessage
          const suffix = validationMessage ? ` — ${validationMessage}` : ""
          this.updateStatus(`Cannot save${suffix}`, "error")
          this.hasPendingChanges = true
          return
        }

        throw new Error("Autosave failed")
      }

      this.lastSavedAt = new Date()
      if (versionAtStart === this.changeVersion) {
        this.hasPendingChanges = false
      }
      this.lastSaveSucceeded = true
      this.lastValidationMessage = null
      this.updateStatus(this.formatSavedMessage(this.lastSavedAt), "saved")

      // Autosave creates nested records server-side but does not update the DOM
      // with the new IDs. Without a refresh, subsequent autosaves/submits will
      // re-send blank ids and duplicate records.
      if (!this.didRefreshAfterAutosave && this.hasBlankNestedIds()) {
        this.refreshQueued = true
      }
    } catch (error) {
      if (error.name === "AbortError") return

      // Network/server errors may be transient; retry. Validation errors are
      // handled above and should not retry until the user fixes the form.
      this.lastSaveSucceeded = false
      this.updateStatus("Save failed. Retrying…", "error")
      this.pendingTimeout = setTimeout(() => this.performSave(), this.debounceDuration)
    } finally {
      this.isSaving = false

      const needsFollowUpSave = this.saveQueuedDuringSave || versionAtStart !== this.changeVersion
      if (needsFollowUpSave) {
        this.saveQueuedDuringSave = false

        if (!this.isSubmitting && this.hasPendingChanges) {
          // Run immediately; any debounce will already have been canceled.
          setTimeout(() => this.performSave(), 0)
        }

        // Do not refresh while a follow-up save is queued; that can discard
        // changes that occurred during the in-flight request.
        return
      }

      if (this.refreshQueued && !this.didRefreshAfterAutosave && this.hasBlankNestedIds()) {
        this.refreshQueued = false
        this.didRefreshAfterAutosave = true
        this.updateStatus("Saved — refreshing…", "saved")
        setTimeout(() => window.location.reload(), 150)
      }
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

    if (!this.lastSaveSucceeded || this.hasPendingChanges) {
      // Stay on the page so the admin can resolve validation errors; otherwise
      // navigating (e.g., to Preview) makes it look like the builder saved.
      const suffix = this.lastValidationMessage ? ` — ${this.lastValidationMessage}` : ""
      this.updateStatus(`Fix errors before leaving this page${suffix}`, "error")
      return
    }

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

  hasBlankNestedIds() {
    // Look for nested id fields with blank values (new records).
    const selectors = [
      'input[name^="survey[sections_attributes]"][name$="[id]"]',
      'input[name^="survey[categories_attributes]"][name$="[id]"]',
      'input[name^="survey[categories_attributes]"][name*="[questions_attributes]"][name$="[id]"]'
    ]

    return selectors.some((selector) => {
      return Array.from(this.element.querySelectorAll(selector)).some((input) => {
        if (!input) return false
        const value = (input.value || "").trim()
        return value.length === 0
      })
    })
  }

  extractFirstErrorMessage(html) {
    if (!html) return null

    try {
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")

      // Prefer the standard error list in the admin survey form.
      const firstLi = doc.querySelector(".bg-rose-50 li")
      const text = firstLi?.textContent?.trim()
      if (text) return text

      const headline = doc.querySelector(".bg-rose-50 h2")?.textContent?.trim()
      if (headline) return headline
    } catch {
      // Ignore parse errors.
    }

    return null
  }
}
