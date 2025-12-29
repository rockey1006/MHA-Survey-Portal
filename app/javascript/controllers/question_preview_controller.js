import { Controller } from "@hotwired/stimulus"

// Live preview for admin survey question editing.
// Keeps the "Preview" portion of a question block in sync while typing.
export default class extends Controller {
  static values = {
    initialOptionPairs: Array
  }

  static targets = [
    "promptInput",
    "descriptionInput",
    "tooltipInput",
    "requiredInput",
    "typeSelect",
    "answerOptionsInput",
    "answerOptionsBlock",
    "promptText",
    "descriptionText",
    "requiredStar",
    "tooltipLine",
    "response"
  ]

  connect() {
    this.update = this.update.bind(this)
    this.handleKeyDown = this.handleKeyDown.bind(this)

    // Track how the backing textarea stores options so edits preserve semantics.
    this.optionsFormat = this.detectOptionsFormat()

    // If the textarea is empty/unparseable but Rails was able to compute option pairs,
    // bootstrap from them so the preview doesn't lose options.
    this.bootstrapOptionsFromInitialPairs()

    this.element.addEventListener("input", this.update)
    this.element.addEventListener("change", this.update)
    this.element.addEventListener("keydown", this.handleKeyDown)
    this.update()
  }

  bootstrapOptionsFromInitialPairs() {
    if (this._bootstrappedOptions) return
    if (!this.hasAnswerOptionsInputTarget) return

    const currentEntries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    if (currentEntries.length) return

    const pairs = Array(this.readInitialOptionPairs() || [])
    if (!pairs.length) return

    const entries = pairs
      .filter((p) => Array.isArray(p) && p.length >= 2)
      .map((p) => ({ label: String(p[0] ?? "").trim(), value: String(p[1] ?? "").trim() }))
      .filter((e) => e.label.length)

    if (!entries.length) return

    // Preserve the seeded meaning: for pairs, keep JSON pairs.
    this.optionsFormat = "json_pairs"
    this._bootstrappedOptions = true
    this.setOptionEntries(entries)
  }

  readInitialOptionPairs() {
    // Prefer Stimulus values API.
    if (this.hasInitialOptionPairsValue) return this.initialOptionPairsValue

    // Fallback for older Stimulus versions: read raw JSON from dataset.
    const raw = this.element?.dataset?.questionPreviewInitialOptionPairsValue
    if (!raw || !raw.length) return null

    try {
      const parsed = JSON.parse(raw)
      return Array.isArray(parsed) ? parsed : null
    } catch {
      return null
    }
  }

  entriesFromInitialPairsForRender() {
    const pairs = Array(this.readInitialOptionPairs() || [])
    if (!pairs.length) return []

    return pairs
      .filter((p) => Array.isArray(p) && p.length >= 2)
      .map((p) => ({
        label: this.normalizeOptionString(p[0]),
        value: this.normalizeOptionString(p[1])
      }))
      .filter((e) => e.label.length)
  }

  disconnect() {
    this.element.removeEventListener("input", this.update)
    this.element.removeEventListener("change", this.update)
    this.element.removeEventListener("keydown", this.handleKeyDown)
  }

  update() {
    this.updatePrompt()
    this.updateDescription()
    this.updateTooltip()
    this.updateRequired()
    this.updateAnswerOptionsVisibility()
    this.updateResponsePreview()
  }

  updatePrompt() {
    if (!this.hasPromptTextTarget) return
    const value = (this.promptInputTarget?.value || "").trim()
    this.promptTextTarget.textContent = value.length ? value : "Untitled question"
  }

  updateDescription() {
    if (!this.hasDescriptionTextTarget) return
    const raw = (this.descriptionInputTarget?.value || "").trim()
    if (!raw.length) {
      this.descriptionTextTarget.innerHTML = '<span class="text-slate-400">Add description</span>'
      return
    }

    // Safe: we are rendering user input, so escape then convert newlines.
    this.descriptionTextTarget.innerHTML = this.escapeHtml(raw).replace(/\r?\n/g, "<br>")
  }

  updateTooltip() {
    if (!this.hasTooltipLineTarget) return
    const raw = (this.tooltipInputTarget?.value || "").trim()
    if (!raw.length) {
      this.tooltipLineTarget.classList.add("hidden")
      this.tooltipLineTarget.textContent = ""
      return
    }

    this.tooltipLineTarget.classList.remove("hidden")
    this.tooltipLineTarget.textContent = `Tooltip: ${raw}`
  }

  updateRequired() {
    if (!this.hasRequiredStarTarget) return
    const required = !!this.requiredInputTarget?.checked
    this.requiredStarTarget.classList.toggle("hidden", !required)
  }

  updateAnswerOptionsVisibility() {
    if (!this.hasAnswerOptionsBlockTarget) return

    const type = (this.typeSelectTarget?.value || "").trim()

    // Only hide the backing textarea when we provide an inline options editor.
    const hidesAnswerOptions = type === "multiple_choice" || type === "dropdown"
    this.answerOptionsBlockTarget.classList.toggle("hidden", hidesAnswerOptions)
  }

  updateResponsePreview() {
    if (!this.hasResponseTarget) return

    const type = (this.typeSelectTarget?.value || "").trim()
    let entries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    if (entries.length === 0) {
      this.bootstrapOptionsFromInitialPairs()
      entries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    }

    if (entries.length === 0 && (type === "multiple_choice" || type === "dropdown")) {
      entries = this.entriesFromInitialPairsForRender()
    }
    const options = entries.map((e) => e.label)

    // Render an interactive preview similar to Google Forms.
    if (type === "short_answer") {
      this.responseTarget.innerHTML =
        '<textarea class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm" rows="3" disabled></textarea>'
      return
    }

    if (type === "evidence") {
      this.responseTarget.innerHTML =
        '<input type="text" class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm" placeholder="https://drive.google.com/..." disabled>'
      return
    }

    if (type === "scale") {
      const lowLabel = options[0] || "Low"
      const highLabel = options[options.length - 1] || "High"
      this.responseTarget.innerHTML = `
        <div class="space-y-1">
          <div class="flex items-center gap-3">
            <span class="text-xs text-slate-500">${this.escapeHtml(lowLabel)}</span>
            <input type="range" class="w-full" min="1" max="5" step="1" disabled>
            <span class="text-xs text-slate-500">${this.escapeHtml(highLabel)}</span>
          </div>
        </div>
      `
      return
    }

    if (type === "multiple_choice" || type === "dropdown") {
      const icon = type === "dropdown" ? "▾" : "○"
      const rows = options
        .map(
          (opt, idx) => `
            <div class="group flex items-center gap-2 text-sm text-slate-800" data-option-row>
              <span class="text-slate-500" aria-hidden="true">${icon}</span>
              <span class="flex-1 cursor-text" data-option-index="${idx}" data-action="click->question-preview#editOption">${this.escapeHtml(
                opt
              )}</span>
              <button
                type="button"
                class="ml-2 inline-flex items-center rounded-md px-2 py-1 text-xs font-semibold text-slate-500 opacity-0 transition-opacity hover:text-rose-600 focus:opacity-100 group-hover:opacity-100"
                aria-label="Delete option"
                title="Delete option"
                data-option-index="${idx}"
                data-action="click->question-preview#removeOption"
              >
                Delete
              </button>
            </div>
          `
        )
        .join("")

      const empty = '<p class="text-xs text-slate-500">No options yet.</p>'
      const add =
        '<button type="button" class="mt-2 text-sm font-semibold text-indigo-600 hover:text-indigo-700" data-action="click->question-preview#addOption">+ Add option</button>'

      this.responseTarget.innerHTML = `
        <div class="space-y-2" data-options-editor>
          ${options.length ? rows : empty}
          ${add}
        </div>
      `
      return
    }

    // Default preview
    this.responseTarget.innerHTML = '<input type="text" class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm" disabled>'
  }

  // ---------------------------
  // Inline editing interactions
  // ---------------------------

  editPrompt(event) {
    event?.preventDefault()
    this.startInlineEditor({
      inputEl: this.promptInputTarget,
      displayEl: this.promptTextTarget,
      placeholder: "Question",
      multiline: false
    })
  }

  editDescription(event) {
    event?.preventDefault()
    this.startInlineEditor({
      inputEl: this.descriptionInputTarget,
      displayEl: this.descriptionTextTarget,
      placeholder: "Add description",
      multiline: true
    })
  }

  editOption(event) {
    const el = event?.currentTarget
    const idx = Number(el?.dataset?.optionIndex)
    if (!Number.isFinite(idx)) return

    const entries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    const current = entries[idx]?.label || ""

    const input = document.createElement("input")
    input.type = "text"
    input.value = current
    input.className = "w-full max-w-xl rounded-md border border-slate-300 px-2 py-1 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"

    const replaceBack = (nextValue) => {
      const next = (nextValue || "").trim()
      if (next.length === 0) {
        entries.splice(idx, 1)
      } else {
        const existing = entries[idx] || { label: "", value: "" }
        const nextEntry = { ...existing, label: next }
        if (!nextEntry.value || String(nextEntry.value).trim().length === 0) nextEntry.value = next
        entries[idx] = nextEntry
      }
      this.setOptionEntries(entries)
      this.updateResponsePreview()
    }

    input.addEventListener("blur", () => replaceBack(input.value))
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
        input.blur()
      }
      if (e.key === "Escape") {
        e.preventDefault()
        this.updateResponsePreview()
      }
    })

    el.replaceWith(input)
    input.focus()
    input.select()
  }

  removeOption(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const el = event?.currentTarget
    const idx = Number(el?.dataset?.optionIndex)
    if (!Number.isFinite(idx)) return

    const entries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    if (idx < 0 || idx >= entries.length) return

    entries.splice(idx, 1)
    this.setOptionEntries(entries)
    this.updateResponsePreview()
  }

  addOption(event) {
    event?.preventDefault()
    const entries = this.parseOptionEntries(this.answerOptionsInputTarget?.value)
    const nextLabel = `Option ${entries.length + 1}`
    const nextValue = this.suggestNextOptionValue(entries, nextLabel)
    entries.push({ label: nextLabel, value: nextValue })
    this.setOptionEntries(entries)
    this.updateResponsePreview()

    // Focus the new option's inline editor.
    requestAnimationFrame(() => {
      const last = this.responseTarget.querySelector('[data-option-index="' + (entries.length - 1) + '"]')
      last?.click()
    })
  }

  handleKeyDown(event) {
    // Allow Enter to start editing prompt when focused on it.
    if (event.key !== "Enter") return
    if (event.target === this.promptTextTarget) {
      event.preventDefault()
      this.editPrompt(event)
    }
  }

  startInlineEditor({ inputEl, displayEl, placeholder, multiline }) {
    if (!inputEl || !displayEl) return

    // Capture the current display element's identity so we can restore it.
    const tagName = displayEl.tagName.toLowerCase()
    const className = displayEl.className
    const targetName = displayEl.dataset.questionPreviewTarget
    const action = displayEl.getAttribute("data-action")

    const textarea = document.createElement(multiline ? "textarea" : "input")
    if (!multiline) textarea.type = "text"

    textarea.value = (inputEl.value || "").trim()
    textarea.placeholder = placeholder || ""
    textarea.className =
      "w-full rounded-md border border-slate-300 bg-white px-2 py-1 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"

    if (multiline) {
      textarea.rows = 2
      textarea.style.resize = "vertical"
    }

    const restoreDisplayEl = () => {
      const restored = document.createElement(tagName)
      restored.className = className
      if (targetName) restored.dataset.questionPreviewTarget = targetName
      if (action) restored.setAttribute("data-action", action)
      textarea.replaceWith(restored)
      return restored
    }

    let canceled = false

    const commit = () => {
      inputEl.value = textarea.value
      inputEl.dispatchEvent(new Event("input", { bubbles: true }))
      restoreDisplayEl()
      this.update()
    }

    const cancel = () => {
      canceled = true
      restoreDisplayEl()
      this.update()
    }

    textarea.addEventListener("blur", () => {
      if (canceled) return
      commit()
    })
    textarea.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.preventDefault()
        cancel()
      }
      if (!multiline && e.key === "Enter") {
        e.preventDefault()
        textarea.blur()
      }
    })

    // Replace the visible display element with the editor.
    displayEl.replaceWith(textarea)

    textarea.focus()
    textarea.select()

  }

  // ---------------------------
  // Options parsing/serialization
  // ---------------------------

  // Backwards-compatible helper (returns labels only)
  parseOptions(raw) {
    return this.parseOptionEntries(raw).map((e) => e.label)
  }

  setOptionEntries(entries) {
    if (!this.hasAnswerOptionsInputTarget) return

    const normalized = Array(entries || [])
      .map((e) => ({
        label: this.normalizeOptionString(e?.label),
        value: this.normalizeOptionString(e?.value ?? e?.label)
      }))
      .filter((e) => e.label.length)

    this.answerOptionsInputTarget.value = this.serializeOptionEntries(normalized)
    this.answerOptionsInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  parseOptionEntries(raw) {
    const text = (raw || "").trim()
    if (!text.length) return []

    const parsed = this.tryParseJsonArray(text)
    if (parsed) {
      return this.normalizeEntries(this.parseEntriesFromJsonArray(parsed))
    }

    // Fallback: newline-first, comma if single-line.
    const parts = text.includes("\n") ? text.split(/\r?\n/) : text.split(",")
    const lines = parts.map((s) => this.normalizeOptionString(s)).filter((s) => s.length)
    return this.normalizeEntries(lines.map((s) => ({ label: s, value: s })))
  }

  detectOptionsFormat() {
    const text = (this.answerOptionsInputTarget?.value || "").trim()
    if (!text.length) return "newline"

    const parsed = this.tryParseJsonArray(text)
    if (!parsed) return "newline"

    if (parsed.some((e) => Array.isArray(e))) return "json_pairs"
    if (parsed.some((e) => e && typeof e === "object" && !Array.isArray(e))) return "json_objects"
    return "json_strings"
  }

  tryParseJsonArray(text) {
    if (!(text.startsWith("[") && text.endsWith("]"))) return null
    try {
      const parsed = JSON.parse(text)
      return Array.isArray(parsed) ? parsed : null
    } catch {
      // A lot of option lists are copied in with smart quotes; normalize and retry.
      const normalized = String(text)
        .replace(/[“”]/g, '"')
        .replace(/[‘’]/g, "'")
      try {
        const parsed = JSON.parse(normalized)
        return Array.isArray(parsed) ? parsed : null
      } catch {
        return null
      }
    }
  }

  parseEntriesFromJsonArray(arr) {
    // Mirrors Question#answer_option_pairs / #answer_options_list behavior.
    const entries = []

    const allStrings = arr.every((e) => typeof e === "string")
    if (allStrings && this.looksLikeAlternatingPairs(arr)) {
      // Legacy oddity: ["1 — Label", "1", "2 — Label", "2", ...]
      this.optionsFormat = "json_pairs"
      for (let i = 0; i < arr.length; i += 2) {
        const label = this.normalizeOptionString(arr[i])
        const value = this.normalizeOptionString(arr[i + 1])
        if (!label.length) continue
        entries.push({ label, value: value || this.extractLeadingValue(label) || label })
      }
      return entries
    }

    for (const entry of arr) {
      if (typeof entry === "string") {
        const s = this.normalizeOptionString(entry)
        if (!s.length) continue
        entries.push({ label: s, value: s })
        continue
      }

      if (Array.isArray(entry)) {
        const label = this.normalizeOptionString(entry[0])
        const value = this.normalizeOptionString(entry[1] ?? entry[0])
        if (!label.length) continue
        entries.push({ label, value: value || label })
        continue
      }

      if (entry && typeof entry === "object") {
        const label = this.normalizeOptionString(entry.label ?? entry["label"] ?? entry.value ?? entry["value"])
        const value = this.normalizeOptionString(entry.value ?? entry["value"] ?? label)
        if (!label.length) continue
        entries.push({ label, value: value || label })
        continue
      }
    }

    return entries
  }

  normalizeEntries(entries) {
    // Merge wrapped/continuation lines and drop value-only duplicates.
    const out = []

    for (const e of Array(entries || [])) {
      const label = this.normalizeOptionString(e?.label)
      const value = this.normalizeOptionString(e?.value ?? label)
      if (!label.length) continue

      if (this.isValueOnlyLine(label) && out.length) {
        const prev = out[out.length - 1]
        const prevLeading = this.extractLeadingValue(prev.label)
        if (prevLeading && prevLeading === label) {
          prev.value = prev.value || label
          continue
        }
      }

      if (out.length && this.looksLikeContinuation(label)) {
        out[out.length - 1].label = `${out[out.length - 1].label} ${label}`.trim()
        continue
      }

      out.push({ label, value: value || label })
    }

    return out
  }

  looksLikeAlternatingPairs(strings) {
    if (strings.length < 2 || strings.length % 2 !== 0) return false
    for (let i = 0; i < strings.length; i += 2) {
      const label = this.normalizeOptionString(strings[i])
      const value = this.normalizeOptionString(strings[i + 1])
      if (!label.length || !value.length) return false
      if (!this.isValueOnlyLine(value)) return false
      const leading = this.extractLeadingValue(label)
      if (!leading || leading !== value) return false
    }
    return true
  }

  looksLikeContinuation(label) {
    if (this.isValueOnlyLine(label)) return false

    const trimmed = String(label || "").trim()

    // Only merge wrapped lines that look like sentence continuations.
    // (E.g. "with limited variation ...")
    if (!/^[a-z]/.test(trimmed)) return false

    return !/^\s*(\d+|[A-Za-z])\s*(—|–|-)/.test(label)
  }

  isValueOnlyLine(label) {
    return /^\s*\d+\s*$/.test(label)
  }

  extractLeadingValue(label) {
    const m = String(label || "").match(/^\s*(\d+)\s*(—|–|-)/)
    return m ? m[1] : ""
  }

  serializeOptionEntries(entries) {
    const format = this.optionsFormat || this.detectOptionsFormat()

    if (format === "json_pairs") {
      return JSON.stringify(entries.map((e) => [e.label, e.value || e.label]))
    }

    if (format === "json_objects") {
      return JSON.stringify(entries.map((e) => ({ label: e.label, value: e.value || e.label })))
    }

    if (format === "json_strings") {
      return JSON.stringify(entries.map((e) => e.label))
    }

    return entries.map((e) => e.label).join("\n")
  }

  suggestNextOptionValue(entries, nextLabel) {
    const values = Array(entries || [])
      .map((e) => String(e?.value ?? "").trim())
      .filter((v) => v.length)

    const allInts = values.length && values.every((v) => /^\d+$/.test(v))
    if (allInts) {
      const max = Math.max(...values.map((v) => Number(v)))
      return String(max + 1)
    }

    return nextLabel
  }

  normalizeOptionString(value) {
    let s = String(value ?? "").trim()
    if (!s.length) return ""

    // Common artifacts from array-ish strings when delimiter-splitting JSON.
    // Examples:
    //   ["Yes"  -> Yes
    //   "No"]  -> No
    if (s.startsWith("[")) s = s.slice(1).trim()
    if (s.endsWith("]")) s = s.slice(0, -1).trim()

    // Remove one layer of surrounding quotes.
    if (
      (s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'")) ||
      (s.startsWith("“") && s.endsWith("”")) ||
      (s.startsWith("‘") && s.endsWith("’"))
    ) {
      s = s.slice(1, -1).trim()
    }

    // Trim stray smart quotes that can appear after splitting.
    s = s.replace(/^[“”‘’]+/, "").replace(/[“”‘’]+$/, "").trim()

    return s
  }

  escapeHtml(input) {
    return String(input)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}
