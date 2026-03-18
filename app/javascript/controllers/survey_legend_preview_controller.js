import { Controller } from "@hotwired/stimulus"
import { renderMarkdown } from "../lib/markdown"

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
      const html = renderMarkdown(previewText)
      this.bodyDisplayTarget.innerHTML = html.length ? `<div class="guidance-text">${html}</div>` : ""
    }
  }
}
