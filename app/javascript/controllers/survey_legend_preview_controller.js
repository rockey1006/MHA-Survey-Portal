import { Controller } from "@hotwired/stimulus"

// Syncs legend form inputs with the live preview in the legend tab.
export default class extends Controller {
  static targets = ["titleInput", "bodyInput", "titleDisplay", "bodyDisplay"]

  connect() {
    this.sync = this.sync.bind(this)
    this.element.addEventListener("input", this.sync)
    this.element.addEventListener("change", this.sync)
    this.sync()
  }

  disconnect() {
    this.element.removeEventListener("input", this.sync)
    this.element.removeEventListener("change", this.sync)
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
    const html = this.renderMarkdown(text)
    if (!html.length) return ""

    return `<div class="guidance-text">${html}</div>`
  }

  renderMarkdown(text) {
    const source = String(text || "").trim()
    if (!source.length) return ""

    const blocks = source.split(/\r?\n\r?\n+/)
    return blocks
      .map((block) => this.renderBlock(block))
      .filter((chunk) => chunk.length)
      .join("")
  }

  renderBlock(block) {
    const lines = String(block)
      .split(/\r?\n/)
      .filter((line) => line.length)

    if (!lines.length) return ""

    if (lines.every((line) => /^-\s+/.test(line))) {
      return `<ul>${lines.map((line) => `<li>${this.inlineMarkdown(line.replace(/^-\s+/, ""))}</li>`).join("")}</ul>`
    }

    if (lines.every((line) => /^\d+\.\s+/.test(line))) {
      return `<ol>${lines.map((line) => `<li>${this.inlineMarkdown(line.replace(/^\d+\.\s+/, ""))}</li>`).join("")}</ol>`
    }

    const heading = lines[0].match(/^(#{1,6})\s+(.+)$/)
    if (heading && lines.length === 1) {
      const level = heading[1].length
      return `<h${level}>${this.inlineMarkdown(heading[2])}</h${level}>`
    }

    if (lines.length === 1 && /^---+$/.test(lines[0])) {
      return "<hr>"
    }

    return `<p>${this.inlineMarkdown(lines.join("\n"))}</p>`
  }

  inlineMarkdown(value) {
    const escaped = this.escapeHtml(value)
    return escaped
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*\*/g, "<strong>$1</strong>")
      .replace(/(^|[^*])\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*(?!\*)/g, "$1<em>$2</em>")
      .replace(/\[([^\]]+)]\(([^\s)]+)(?:\s+"[^"]*")?\)/g, (_full, label, href) => {
        const safeHref = this.normalizeHref(href)
        if (!safeHref) return label

        const attrs = /^https?:\/\//i.test(safeHref)
          ? ' target="_blank" rel="noopener noreferrer"'
          : ""

        return `<a href="${safeHref}"${attrs}>${label}</a>`
      })
      .replace(/(^|[\s(>])(https?:\/\/[^\s<]+|www\.[^\s<]+)/gi, (_full, lead, href) => {
        const safeHref = this.normalizeHref(href)
        if (!safeHref) return `${lead}${href}`

        return `${lead}<a href="${safeHref}" target="_blank" rel="noopener noreferrer">${href}</a>`
      })
      .replace(/&lt;br\s*\/?&gt;/gi, "<br>")
      .replace(/\r?\n/g, "<br>")
  }

  normalizeHref(rawHref) {
    const href = String(rawHref || "").trim()
    if (!href.length) return null

    if (/^www\./i.test(href)) return `https://${href}`
    if (/^https?:\/\//i.test(href)) return href
    if (/^mailto:/i.test(href)) return href
    if (/^tel:/i.test(href)) return href
    if (/^\//.test(href)) return href
    if (/^#/.test(href)) return href

    return null
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
