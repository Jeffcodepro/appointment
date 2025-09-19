// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 4000 }
  }

  connect() {
    // Remove duplicados com o mesmo texto
    const siblings = Array.from(document.querySelectorAll(".alerts-stack .alert"))
    siblings.forEach((el) => {
      if (el !== this.element && el.textContent.trim() === this.element.textContent.trim()) {
        el.remove()
      }
    })

    // Garante que a animação de entrada rode
    requestAnimationFrame(() => this.element.classList.add("show"))

    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => this.close(), this.timeoutValue)
    }
  }

  close() {
    const el = this.element

    const onEnd = () => {
      el.removeEventListener("transitionend", onEnd)
      el.removeEventListener("animationend", onEnd)
      if (this.fallback) clearTimeout(this.fallback)
      el.remove()
    }

    // Ouça antes de mudar a classe
    el.addEventListener("transitionend", onEnd, { once: true })
    el.addEventListener("animationend", onEnd,  { once: true })

    // Força reflow e dispara saída
    void el.offsetWidth
    el.classList.remove("show")

    // Fallback se não houver transição
    this.fallback = setTimeout(onEnd, 400)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
    if (this.fallback) clearTimeout(this.fallback)
  }
}
