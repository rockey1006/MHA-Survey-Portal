import { Controller } from "@hotwired/stimulus"

// Adds common markdown keyboard shortcuts for textarea-style editors.
export default class extends Controller {
  connect() {
    this.handleShortcut = this.handleShortcut.bind(this)
    this.element.addEventListener("keydown", this.handleShortcut)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.handleShortcut)
  }

  handleShortcut(event) {
    if ((!event.ctrlKey && !event.metaKey) || event.altKey) return
    if (event.defaultPrevented) return

    const target = event.target
    if (!this.supportsTextSelection(target)) return

    const key = event.key.toLowerCase()

    if (key === "b") {
      event.preventDefault()
      this.wrapSelection(target, "**", "**")
      return
    }

    if (key === "i") {
      event.preventDefault()
      this.wrapSelection(target, "*", "*")
      return
    }

    if (key === "k") {
      event.preventDefault()
      this.wrapLink(target)
      return
    }

    if (key === "8" && event.shiftKey) {
      event.preventDefault()
      this.toggleListPrefix(target, "- ")
      return
    }

    if (key === "7" && event.shiftKey) {
      event.preventDefault()
      this.toggleOrderedList(target)
    }
  }

  supportsTextSelection(target) {
    if (!(target instanceof HTMLTextAreaElement)) return false
    return !target.disabled && !target.readOnly
  }

  wrapSelection(target, openTag, closeTag) {
    const start = target.selectionStart
    const end = target.selectionEnd
    const selected = target.value.slice(start, end)
    const fallback = openTag + "text" + closeTag
    const replacement = selected.length ? `${openTag}${selected}${closeTag}` : fallback

    target.setRangeText(replacement, start, end, "select")

    if (!selected.length) {
      const cursorStart = start + openTag.length
      const cursorEnd = cursorStart + 4
      target.setSelectionRange(cursorStart, cursorEnd)
    }

    this.dispatchInput(target)
  }

  wrapLink(target) {
    const start = target.selectionStart
    const end = target.selectionEnd
    const selected = target.value.slice(start, end) || "link text"
    const replacement = `[${selected}](https://example.com)`

    target.setRangeText(replacement, start, end, "end")

    const urlStart = start + replacement.indexOf("https://example.com")
    const urlEnd = urlStart + "https://example.com".length
    target.setSelectionRange(urlStart, urlEnd)

    this.dispatchInput(target)
  }

  toggleListPrefix(target, prefix) {
    const { start, end, lines, rangeStart, rangeEnd } = this.selectedLines(target)
    const hasPrefix = lines.every((line) => line.startsWith(prefix))

    const updated = lines.map((line) => {
      if (hasPrefix) return line.replace(prefix, "")
      if (!line.trim().length) return line
      return `${prefix}${line}`
    })

    target.setRangeText(updated.join("\n"), start, end, "select")
    target.setSelectionRange(rangeStart, rangeEnd)
    this.dispatchInput(target)
  }

  toggleOrderedList(target) {
    const { start, end, lines, rangeStart, rangeEnd } = this.selectedLines(target)
    const numberedPattern = /^\d+\.\s/
    const hasNumbers = lines.every((line) => numberedPattern.test(line) || !line.trim().length)

    const updated = lines.map((line, idx) => {
      if (!line.trim().length) return line
      if (hasNumbers) return line.replace(numberedPattern, "")
      return `${idx + 1}. ${line}`
    })

    target.setRangeText(updated.join("\n"), start, end, "select")
    target.setSelectionRange(rangeStart, rangeEnd)
    this.dispatchInput(target)
  }

  selectedLines(target) {
    const raw = target.value
    const selStart = target.selectionStart
    const selEnd = target.selectionEnd
    const start = raw.lastIndexOf("\n", selStart - 1) + 1
    const lineEndIndex = raw.indexOf("\n", selEnd)
    const end = lineEndIndex === -1 ? raw.length : lineEndIndex
    const block = raw.slice(start, end)

    return {
      start,
      end,
      lines: block.split("\n"),
      rangeStart: start,
      rangeEnd: start + block.length
    }
  }

  dispatchInput(target) {
    target.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
