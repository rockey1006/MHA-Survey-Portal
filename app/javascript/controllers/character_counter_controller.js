import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter"]

  connect() {
    this.update()
  }

  update() {
    if (!this.hasInputTarget || !this.hasCounterTarget) return

    const max = this.maxLength()
    const current = (this.inputTarget.value || "").length

    if (max) {
      this.counterTarget.textContent = `${current}/${max} characters`
    } else {
      this.counterTarget.textContent = `${current} characters`
    }
  }

  maxLength() {
    const raw = this.inputTarget.getAttribute("maxlength")
    const parsed = raw ? parseInt(raw, 10) : NaN
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null
  }

  input() {
    this.update()
  }
}
