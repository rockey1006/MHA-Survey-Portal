import { Controller } from "@hotwired/stimulus"

// Builds the survey sidebar that keeps sections and categories in sync.
export default class extends Controller {
  static targets = ["panel", "sidebarList", "assignmentField", "assignmentLabel", "categoriesContainer"]
  static values = { activePanelKey: String }

  connect() {
    this.panelActiveClasses = ["ring-2", "ring-indigo-500", "ring-offset-1"]
    this.selectedCategoryKey = null
    this.sectionButtons = new Map()
    this.categoryButtons = new Map()
    this.sectionContainers = new Map()
    this.draggedCategoryKey = null
    this.dragHoverSectionKey = null
    this.categoryHoverKey = null

    this.handleSectionsChanged = this.refreshStructure.bind(this)
    this.handleCategoriesChanged = this.refreshStructure.bind(this)
    this.handleFocus = this.handleFocus.bind(this)

    window.addEventListener("survey:sections-changed", this.handleSectionsChanged)
    window.addEventListener("survey:categories-changed", this.handleCategoriesChanged)
    this.element.addEventListener("focusin", this.handleFocus, true)

    this.refreshStructure()
  }

  disconnect() {
    window.removeEventListener("survey:sections-changed", this.handleSectionsChanged)
    window.removeEventListener("survey:categories-changed", this.handleCategoriesChanged)
    this.element.removeEventListener("focusin", this.handleFocus, true)
  }

  panelTargetConnected() {
    this.refreshStructure()
  }

  panelTargetDisconnected() {
    this.refreshStructure()
  }

  syncPanelLabel(event) {
    const panel = event.target.closest("[data-panel-key]")
    if (!panel) return

    const fallback = panel.dataset.panelType === "section" ? "Untitled section" : "Untitled category"
    panel.dataset.panelLabel = event.target.value.trim() || fallback
    this.refreshStructure()
  }

  refreshStructure() {
    if (!this.hasSidebarListTarget) return

    if (this.selectedCategoryKey && !this.findPanelByKey(this.selectedCategoryKey)) {
      this.selectedCategoryKey = null
    }
    if (this.activePanelKeyValue && !this.findPanelByKey(this.activePanelKeyValue)) {
      this.activePanelKeyValue = null
    }

    const sections = this.visiblePanels("section")
    const categories = this.visiblePanels("category")

    this.sectionLabelMap = new Map([["", "No section"]])
    sections.forEach((panel) => {
      const uid = panel.dataset.sectionUid || ""
      this.sectionLabelMap.set(uid, this.panelLabel(panel, "Untitled section"))
    })

    const validSectionUids = new Set(Array.from(this.sectionLabelMap.keys()))
    const buckets = this.buildCategoryBuckets(categories, validSectionUids)

    this.sectionButtons = new Map()
    this.categoryButtons = new Map()
    this.sectionContainers = new Map()

    const fragment = document.createDocumentFragment()
    fragment.appendChild(
      this.buildSectionBlock(
        { uid: "", label: "No section", panelKey: null, virtual: true },
        buckets.get("") || []
      )
    )

    sections.forEach((panel) => {
      const record = {
        uid: panel.dataset.sectionUid || "",
        label: this.panelLabel(panel, "Untitled section"),
        panelKey: panel.dataset.panelKey || null,
        virtual: false
      }
      fragment.appendChild(this.buildSectionBlock(record, buckets.get(record.uid) || []))
    })

    this.sidebarListTarget.innerHTML = ""
    this.sidebarListTarget.appendChild(fragment)

    this.updateAssignmentLabels()
    this.refreshSelectionStyles()
  }

  visiblePanels(type) {
    return this.panelElements().filter((panel) => panel.dataset.panelType === type && this.panelIsUsable(panel))
  }

  panelIsUsable(panel) {
    if (!panel.isConnected) return false
    if (panel.closest("template")) return false

    const destroyInput = panel.querySelector('input[name$="[_destroy]"]')
    if (destroyInput) {
      if (destroyInput.type === "checkbox" && destroyInput.checked) return false
      if (destroyInput.type !== "checkbox" && destroyInput.value === "1") return false
    }

    if (panel.classList.contains("hidden")) return false
    if (panel.style.display === "none") return false

    return true
  }

  buildCategoryBuckets(categories, validSectionUids) {
    const buckets = new Map()
    categories.forEach((panel) => {
      let sectionUid = panel.dataset.sectionUid || ""
      if (sectionUid && !validSectionUids.has(sectionUid)) {
        sectionUid = ""
      }
      if (!buckets.has(sectionUid)) buckets.set(sectionUid, [])
      buckets.get(sectionUid).push(panel)
    })
    return buckets
  }

  buildSectionBlock(record, categoryPanels) {
    const wrapper = document.createElement("div")
    wrapper.className = "rounded-lg border border-slate-200 bg-white p-3"

    const button = document.createElement("button")
    button.type = "button"
    button.className = "flex w-full items-center justify-between rounded border border-transparent px-2 py-1 text-left text-sm font-semibold text-slate-800"
    button.dataset.sectionUid = record.uid
    button.addEventListener("click", (event) => {
      event.preventDefault()
      this.handleSectionSelection(record)
    })

    const labelSpan = document.createElement("span")
    labelSpan.textContent = record.label
    const countBadge = document.createElement("span")
    countBadge.className = "rounded-full bg-slate-100 px-2 text-xs font-medium text-slate-600"
    countBadge.textContent = categoryPanels.length.toString()

    button.appendChild(labelSpan)
    button.appendChild(countBadge)

  const sectionKey = this.sectionKeyFor(record.uid)
  this.sectionButtons.set(sectionKey, button)
  this.sectionContainers.set(sectionKey, wrapper)

  const handleDragOver = (event) => this.handleSectionDragOver(record, event)
  const handleDragLeave = (event) => this.handleSectionDragLeave(record, event)
  const handleDrop = (event) => this.handleSectionDrop(record, event)
  wrapper.addEventListener("dragover", handleDragOver)
  wrapper.addEventListener("dragleave", handleDragLeave)
  wrapper.addEventListener("drop", handleDrop)

    const list = document.createElement("div")
    list.className = "mt-2 space-y-1"

    if (categoryPanels.length === 0) {
      const empty = document.createElement("p")
      empty.className = "text-xs text-slate-400"
      empty.textContent = record.virtual
        ? "Unassigned categories will collect here."
        : "No categories yet."
      list.appendChild(empty)
    } else {
      categoryPanels.forEach((panel) => list.appendChild(this.buildCategoryButton(panel)))
    }

    wrapper.appendChild(button)
    wrapper.appendChild(list)
    return wrapper
  }

  buildCategoryButton(panel) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "w-full rounded border border-transparent px-2 py-1 text-left text-sm text-slate-700 hover:border-indigo-200 hover:bg-indigo-50"
    button.dataset.panelKey = panel.dataset.panelKey
    button.draggable = true
    button.addEventListener("click", (event) => {
      event.preventDefault()
      event.stopPropagation()
      this.handleCategorySelection(panel.dataset.panelKey)
    })
    button.addEventListener("dragstart", (event) => this.handleCategoryDragStart(panel.dataset.panelKey, event))
    button.addEventListener("dragend", () => this.handleCategoryDragEnd(panel.dataset.panelKey))
    button.addEventListener("dragover", (event) => this.handleCategoryDragOver(panel.dataset.panelKey, event))
    button.addEventListener("dragleave", (event) => this.handleCategoryDragLeave(panel.dataset.panelKey, event))
    button.addEventListener("drop", (event) => this.handleCategoryDrop(panel.dataset.panelKey, event))

    const label = document.createElement("span")
    label.textContent = this.panelLabel(panel, "Untitled category")
    button.appendChild(label)

    this.categoryButtons.set(panel.dataset.panelKey, button)
    return button
  }

  handleCategoryDragStart(panelKey, event) {
    this.draggedCategoryKey = panelKey
    if (event?.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", panelKey)
    }
    this.setCategoryDragging(panelKey, true)
  }

  handleCategoryDragEnd(panelKey) {
    if (this.draggedCategoryKey === panelKey) {
      this.draggedCategoryKey = null
    }
    this.setCategoryDragging(panelKey, false)
    this.clearCategoryHover()
    this.clearSectionHover()
  }

  handleCategoryDragOver(panelKey, event) {
    if (!this.draggedCategoryKey || this.draggedCategoryKey === panelKey) return
    event.preventDefault()
    if (event?.dataTransfer) event.dataTransfer.dropEffect = "move"
    this.setCategoryHover(panelKey)
  }

  handleCategoryDragLeave(panelKey, event) {
    if (!this.draggedCategoryKey) return
    if (event.currentTarget.contains(event.relatedTarget)) return
    if (this.categoryHoverKey === panelKey) this.clearCategoryHover()
  }

  handleCategoryDrop(panelKey, event) {
    if (!this.draggedCategoryKey || this.draggedCategoryKey === panelKey) return
    event.preventDefault()
    const position = this.dropPosition(event)
    this.reorderCategoryPanels(this.draggedCategoryKey, panelKey, position)
    const targetPanel = this.findPanelByKey(panelKey)
    const targetSectionUid = targetPanel?.dataset.sectionUid || ""
    const draggedPanel = this.findPanelByKey(this.draggedCategoryKey)
    const currentSectionUid = draggedPanel?.dataset.sectionUid || ""
    if (targetSectionUid !== currentSectionUid) {
      this.assignCategoryToSection(this.draggedCategoryKey, targetSectionUid)
    }
    this.draggedCategoryKey = null
    this.clearCategoryHover()
    this.clearSectionHover()
  }

  handleCategorySelection(panelKey) {
    if (this.selectedCategoryKey === panelKey) {
      this.selectedCategoryKey = null
      this.refreshSelectionStyles()
      return
    }

    this.selectedCategoryKey = panelKey
    this.activePanelKeyValue = panelKey

    const panel = this.findPanelByKey(panelKey)
    this.scrollPanelIntoView(panel)
    this.refreshSelectionStyles()
  }

  handleSectionSelection(record) {
    const sectionUid = record.uid || ""

    if (this.selectedCategoryKey) {
      this.assignCategoryToSection(this.selectedCategoryKey, sectionUid)
      return
    }

    if (record.panelKey) {
      this.activePanelKeyValue = record.panelKey
      const panel = this.findPanelByKey(record.panelKey)
      this.scrollPanelIntoView(panel)
      this.refreshSelectionStyles()
    }
  }

  handleSectionDragOver(record, event) {
    if (!this.draggedCategoryKey) return
    event.preventDefault()
    if (event?.dataTransfer) event.dataTransfer.dropEffect = "move"
    this.setSectionHover(record.uid)
  }

  handleSectionDragLeave(record, event) {
    if (!this.draggedCategoryKey) return
    if (event.currentTarget.contains(event.relatedTarget)) return
    if (this.dragHoverSectionKey === this.sectionKeyFor(record.uid)) {
      this.clearSectionHover()
    }
  }

  handleSectionDrop(record, event) {
    if (!this.draggedCategoryKey) return
    event.preventDefault()
    const categoryKey = this.draggedCategoryKey
    this.assignCategoryToSection(categoryKey, record.uid || "")
    this.draggedCategoryKey = null
    this.setCategoryDragging(categoryKey, false)
    this.clearSectionHover()
  }

  assignCategoryToSection(panelKey, sectionUid) {
    const panel = this.findPanelByKey(panelKey)
    if (!panel) return

    const field = this.assignmentFieldTargets.find((input) => input.dataset.panelKey === panelKey)
    if (field) {
      field.value = sectionUid || ""
      field.dispatchEvent(new Event("input", { bubbles: true }))
      field.dispatchEvent(new Event("change", { bubbles: true }))
    }

    panel.dataset.sectionUid = sectionUid || ""
    this.updateAssignmentLabels()
    this.notifyCategoriesChanged()
  }

  updateAssignmentLabels() {
    if (!this.hasAssignmentLabelTarget) return

    this.assignmentLabelTargets.forEach((label) => {
      const panelKey = label.dataset.panelKey
      const panel = this.findPanelByKey(panelKey)
      if (!panel) return

      const sectionUid = panel.dataset.sectionUid || ""
      if (!sectionUid) {
        label.textContent = "No section selected"
        return
      }

      const sectionName = this.sectionLabelMap?.get(sectionUid)
      label.textContent = sectionName ? `In ${sectionName}` : "Linked to removed section"
    })
  }

  refreshSelectionStyles() {
    const activeKey = this.activePanelKeyValue || ""

    this.panelElements().forEach((panel) => {
      const isActive = panel.dataset.panelKey === activeKey
      this.panelActiveClasses.forEach((className) => {
        panel.classList.toggle(className, isActive)
      })
    })

    this.categoryButtons.forEach((button, key) => {
      const isSelected = this.selectedCategoryKey === key
      button.classList.toggle("border-indigo-300", isSelected)
      button.classList.toggle("bg-indigo-50", isSelected)
      button.classList.toggle("text-indigo-900", isSelected)
    })

    const hasSelection = Boolean(this.selectedCategoryKey)
    this.sectionButtons.forEach((button) => {
      button.classList.toggle("border-indigo-300", hasSelection)
      button.classList.toggle("bg-indigo-50", hasSelection)
    })
  }

  handleFocus(event) {
    const panel = event.target.closest("[data-panel-key]")
    if (!panel) return
    this.activePanelKeyValue = panel.dataset.panelKey
    this.refreshSelectionStyles()
  }

  activePanelKeyValueChanged() {
    this.refreshSelectionStyles()
  }

  panelLabel(panel, fallback) {
    return (panel.dataset.panelLabel && panel.dataset.panelLabel.trim()) || fallback
  }

  findPanelByKey(panelKey) {
    if (!panelKey) return null
    return this.panelElements().find((panel) => panel.dataset.panelKey === panelKey) || null
  }

  scrollPanelIntoView(panel) {
    if (!panel || typeof panel.scrollIntoView !== "function") return
    panel.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  sectionKeyFor(uid) {
    return uid && uid.length > 0 ? uid : "__none__"
  }

  setCategoryDragging(panelKey, isDragging) {
    const button = this.categoryButtons.get(panelKey)
    if (!button) return
    button.classList.toggle("border-dashed", isDragging)
    button.classList.toggle("border-slate-400", isDragging)
    button.classList.toggle("opacity-60", isDragging)
  }

  setCategoryHover(panelKey) {
    if (this.categoryHoverKey === panelKey) return
    this.clearCategoryHover()
    this.categoryHoverKey = panelKey
    this.toggleCategoryHoverClasses(panelKey, true)
  }

  clearCategoryHover() {
    if (!this.categoryHoverKey) return
    this.toggleCategoryHoverClasses(this.categoryHoverKey, false)
    this.categoryHoverKey = null
  }

  toggleCategoryHoverClasses(panelKey, isActive) {
    const button = this.categoryButtons.get(panelKey)
    if (!button) return
    button.classList.toggle("border-indigo-400", isActive)
    button.classList.toggle("bg-indigo-50", isActive)
  }

  setSectionHover(sectionUid) {
    const mapKey = this.sectionKeyFor(sectionUid)
    if (this.dragHoverSectionKey === mapKey) return
    this.clearSectionHover()
    this.dragHoverSectionKey = mapKey
    this.toggleSectionHoverClasses(mapKey, true)
  }

  clearSectionHover() {
    if (!this.dragHoverSectionKey) return
    this.toggleSectionHoverClasses(this.dragHoverSectionKey, false)
    this.dragHoverSectionKey = null
  }

  toggleSectionHoverClasses(mapKey, isActive) {
    const button = this.sectionButtons.get(mapKey)
    if (button) {
      button.classList.toggle("border-indigo-400", isActive)
      button.classList.toggle("bg-indigo-50", isActive)
    }
    const container = this.sectionContainers.get(mapKey)
    if (container) {
      container.classList.toggle("border-indigo-300", isActive)
      container.classList.toggle("bg-indigo-50", isActive)
    }
  }

  dropPosition(event) {
    const target = event.currentTarget
    if (!target?.getBoundingClientRect) return "after"
    const rect = target.getBoundingClientRect()
    const offset = event.clientY - rect.top
    return offset < rect.height / 2 ? "before" : "after"
  }

  reorderCategoryPanels(sourceKey, targetKey, position) {
    const container = this.categoryFieldContainer
    if (!container) return

    const sourcePanel = this.findPanelByKey(sourceKey)
    const targetPanel = this.findPanelByKey(targetKey)
    if (!sourcePanel || !targetPanel || sourcePanel === targetPanel) return
    if (!container.contains(sourcePanel) || !container.contains(targetPanel)) return

    if (position === "before") {
      container.insertBefore(sourcePanel, targetPanel)
    } else {
      targetPanel.insertAdjacentElement("afterend", sourcePanel)
    }

    this.selectedCategoryKey = sourceKey
    this.activePanelKeyValue = sourceKey
    this.notifyCategoriesChanged()
  }

  get categoryFieldContainer() {
    if (this.hasCategoriesContainerTarget) return this.categoriesContainerTarget
    return this.element.querySelector("[data-category-fields-target='container']")
  }

  notifyCategoriesChanged() {
    window.dispatchEvent(new CustomEvent("survey:categories-changed"))
  }

  panelElements() {
    const scope = this.element.closest("form") || document
    return Array.from(scope.querySelectorAll("[data-survey-structure-target='panel']"))
  }
}
