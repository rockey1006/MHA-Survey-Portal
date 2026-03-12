import { Controller } from "@hotwired/stimulus"

// Syncs legend form inputs with the live preview in the legend tab.
export default class extends Controller {
  static targets = ["titleInput", "bodyInput", "titleDisplay", "bodyDisplay"]

  connect() {
    this.sync()
  }

  sync() {
    const title = this.hasTitleInputTarget ? this.titleInputTarget.value.trim() : ""
    const body = this.hasBodyInputTarget ? this.bodyInputTarget.value.trim() : ""

    if (this.hasTitleDisplayTarget) {
      this.titleDisplayTarget.textContent = title || "Rating Scale Reference"
    }

    if (this.hasBodyDisplayTarget) {
      const previewText = body || "Legend body preview will appear here as you type."
      this.bodyDisplayTarget.innerHTML = this.renderGuidanceText(previewText)
    }
  }

  renderGuidanceText(text) {
    const sections = this.parseSections(text)
    if (!sections.length) {
      return ""
    }

    return `<div class="guidance-text">${sections
      .map((section) => {
        const title = section.title
          ? `<h3 class="guidance-section-title">${this.escapeHtml(section.title)}</h3>`
          : ""

        const paragraphs = section.paragraphs
          .map((paragraph) => `<p class="guidance-paragraph">${this.escapeHtml(paragraph)}</p>`)
          .join("")

        const bullets = section.bullets.length
          ? `<ul class="guidance-list">${section.bullets
              .map((bullet) => `<li>${this.escapeHtml(bullet)}</li>`)
              .join("")}</ul>`
          : ""

        return `<div class="guidance-section">${title}${paragraphs}${bullets}</div>`
      })
      .join("")}</div>`
  }

  parseSections(text) {
    const normalized = (text || "").trim()
    if (!normalized) {
      return []
    }

    return normalized
      .split(/\r?\n\r?\n+/)
      .map((chunk) => this.parseSection(chunk))
      .filter(Boolean)
  }

  parseSection(chunk) {
    const lines = chunk
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0)

    if (!lines.length) {
      return null
    }

    let title = null
    const contentLines = [...lines]

    if (contentLines.length >= 2 && /^-{2,}$/.test(contentLines[1])) {
      title = contentLines.shift()
      contentLines.shift()
    }

    const allBullets = contentLines.length > 0 && contentLines.every((line) => line.startsWith("- "))
    if (allBullets) {
      return {
        title,
        paragraphs: [],
        bullets: contentLines.map((line) => line.replace(/^-\s*/, ""))
      }
    }

    return {
      title,
      paragraphs: contentLines,
      bullets: []
    }
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
