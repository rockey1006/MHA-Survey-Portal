import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    message: String
  }

  confirm(event) {
    const message = this.messageValue || "Are you sure you want to continue?"
    if (!window.confirm(message)) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
}
