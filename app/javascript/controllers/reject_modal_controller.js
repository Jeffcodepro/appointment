// app/javascript/controllers/reject_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "form"]

  open() {
    this.overlayTarget.hidden = false
    document.documentElement.classList.add("custom-modal-open")
    setTimeout(() => this.overlayTarget?.querySelector("input,textarea,button")?.focus(), 0)
    this._esc = (e) => { if (e.key === "Escape") this.close() }
    this._click = (e) => { if (e.target === this.overlayTarget) this.close() }
    document.addEventListener("keydown", this._esc)
    this.overlayTarget.addEventListener("click", this._click)
  }

  close() {
    this.overlayTarget.hidden = true
    document.documentElement.classList.remove("custom-modal-open")
    document.removeEventListener("keydown", this._esc)
    this.overlayTarget.removeEventListener("click", this._click)
  }
}
