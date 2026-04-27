import { Controller } from "@hotwired/stimulus"
import { renderMarkdown } from "lib/markdown"

export default class extends Controller {
  static targets = ["source", "output"]

  connect() {
    if (!this.hasSourceTarget || !this.hasOutputTarget) return

    const markdown = this.sourceTarget.value || this.sourceTarget.textContent || ""
    this.outputTarget.innerHTML = renderMarkdown(markdown)
  }
}
