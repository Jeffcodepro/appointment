// app/javascript/controllers/day_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this._onKeyDown = (e) => { if (e.key === "Escape") this.close() }
  }

  open(event) {
    event?.preventDefault?.()

    // 1) força o Turbo Frame a buscar o conteúdo do dia
    const frame = document.getElementById("day-events-modal-body")
    if (frame) {
      const url = this.urlValue || this.element.getAttribute("href")
      frame.innerHTML = '<div class="p-4 text-center text-muted">Carregando…</div>'
      if (url) frame.setAttribute("src", url)
    }

    // 2) abre modal (CSS-only)
    const modalEl = document.getElementById("dayEventsModal")
    if (modalEl) {
      modalEl.classList.add("is-open")
      modalEl.setAttribute("aria-hidden", "false")
      document.body.classList.add("custom-modal-open")
      document.addEventListener("keydown", this._onKeyDown, { passive: true })
    }
  }

  close(event) {
    event?.preventDefault?.()
    const modalEl = document.getElementById("dayEventsModal")
    if (!modalEl) return
    modalEl.classList.remove("is-open")
    modalEl.setAttribute("aria-hidden", "true")
    document.body.classList.remove("custom-modal-open")
    document.removeEventListener("keydown", this._onKeyDown)
  }
}
