import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    // auto-dismiss
    this.timer = setTimeout(() => this.close(), this.timeoutValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  close() {
    if (this.timer) clearTimeout(this.timer)
    if (this._closed) return
    this._closed = true

    // tenta animar; se não houver CSS, remove no fallback
    this.element.classList.add("flash-fade-out")

    let removed = false
    const remove = () => {
      if (removed) return
      removed = true
      this.element?.remove()
    }

    // remove ao final da animação (se houver)
    this.element.addEventListener("animationend", remove, { once: true })
    // fallback: garante remoção mesmo sem CSS (250–400ms é ok)
    setTimeout(remove, 300)
  }
}
