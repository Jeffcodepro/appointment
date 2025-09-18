// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    // Evita toasts duplicados lado a lado: remove irmãos idênticos
    const siblings = Array.from(document.querySelectorAll(".toast.show"))
    siblings.forEach((el) => {
      if (el !== this.element && el.textContent.trim() === this.element.textContent.trim()) {
        el.remove()
      }
    })

    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => this.close(), this.timeoutValue)
    }
  }

  close() {
    this.element.classList.remove("show")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }

  disconnect() { if (this.timer) clearTimeout(this.timer) }
}
