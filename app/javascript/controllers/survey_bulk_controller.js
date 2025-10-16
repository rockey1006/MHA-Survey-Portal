import { Controller } from "@hotwired/stimulus"

// Handles bulk selection and grouping interactions on the admin survey index
export default class extends Controller {
  static targets = ["checkbox", "selectAll", "submit", "counter"]

  connect() {
    this.updateSubmitState()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })
    this.updateSubmitState()
  }

  markChanged(event) {
    const checkbox = event.target
    this.syncLinkedCheckboxes(checkbox)
    this.updateSubmitState()
  }

  updateSubmitState() {
    const selectedCount = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    const totalCount = this.checkboxTargets.length

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = selectedCount === 0
    }

    if (this.hasSelectAllTarget) {
      const selectAll = this.selectAllTarget
      if (totalCount === 0) {
        selectAll.indeterminate = false
        selectAll.checked = false
        return
      }

      selectAll.indeterminate = selectedCount > 0 && selectedCount < totalCount
      selectAll.checked = selectedCount > 0 && selectedCount === totalCount
    }

    if (this.hasCounterTarget) {
      const totalLabel = totalCount === 1 ? "survey" : "surveys"
      const message = selectedCount === 0
        ? "No surveys selected."
        : `Selected ${selectedCount} of ${totalCount} ${totalLabel}.`

      this.counterTarget.textContent = message
      this.counterTarget.classList.toggle("admin-surveys-selection-summary--active", selectedCount > 0)
    }
  }

  syncLinkedCheckboxes(source) {
    const surveyId = source.dataset.surveyBulkSurveyId
    if (!surveyId) return

    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox === source) return
      if (checkbox.dataset.surveyBulkSurveyId === surveyId) {
        checkbox.checked = source.checked
      }
    })
  }
}
