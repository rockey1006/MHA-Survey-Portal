import { Controller } from "@hotwired/stimulus"

// Keeps category section dropdowns synchronized with the current section list.
export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.sections = []
    this.handleSectionsChanged = this.handleSectionsChanged.bind(this)
    window.addEventListener("survey:sections-changed", this.handleSectionsChanged)
    this.seedSectionsFromDom()
    this.selectTargets.forEach((select) => this.applySectionsToSelect(select))
  }

  disconnect() {
    window.removeEventListener("survey:sections-changed", this.handleSectionsChanged)
  }

  selectTargetConnected(element) {
    this.applySectionsToSelect(element)
  }

  handleSectionsChanged(event) {
    this.sections = event.detail?.sections || []
    this.selectTargets.forEach((select) => this.applySectionsToSelect(select))
  }

  seedSectionsFromDom() {
    if (this.sections.length > 0) return

    const sourceSelect = this.selectTargets[0]
    if (!sourceSelect) return

    this.sections = Array.from(sourceSelect.options)
      .filter((option) => !option.dataset.blankOption && option.value?.length)
      .map((option) => ({ uid: option.value, label: option.textContent.trim() || "Untitled section" }))
  }

  applySectionsToSelect(select) {
    if (!select) return

    const blankLabel = select.dataset.blankLabel || "No section"
    let blankOption = select.querySelector("option[data-blank-option]")
    if (!blankOption) {
      blankOption = document.createElement("option")
      blankOption.value = ""
      blankOption.dataset.blankOption = "true"
      select.insertBefore(blankOption, select.firstChild)
    }
    blankOption.textContent = blankLabel

    const previousValue = select.value

    Array.from(select.options).forEach((option) => {
      if (!option.dataset.blankOption) option.remove()
    })

    this.sections.forEach((section) => {
      const option = document.createElement("option")
      option.value = section.uid
      option.textContent = section.label || "Untitled section"
      select.appendChild(option)
    })

    if (previousValue && this.sections.some((section) => section.uid === previousValue)) {
      select.value = previousValue
    } else {
      select.value = ""
    }
  }
}
