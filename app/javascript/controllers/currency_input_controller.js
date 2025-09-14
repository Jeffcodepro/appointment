// app/javascript/controllers/currency_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { min: Number, max: Number }

  connect() {
    // Blindagem: se o Simple Form inferir number, força text
    if (this.element.type !== "text") this.element.setAttribute("type", "text")
    this.normalize()
  }

  format() {
    const input = this.element
    const digits = (input.value || "").replace(/\D/g, "")

    if (!digits.length) {
      input.value = ""
      return
    }

    const cents   = digits.padStart(3, "0")
    const intPart = cents.slice(0, -2).replace(/^0+/, "") || "0"
    const decPart = cents.slice(-2)

    input.value = this._group(intPart) + "," + decPart
  }

  normalize() {
    const v = (this.element.value || "").trim()
    if (v === "") return

    const digits  = v.replace(/\D/g, "")
    const padded  = digits.length ? digits.padStart(3, "0") : "000"
    const intPart = padded.slice(0, -2).replace(/^0+/, "") || "0"
    const decPart = padded.slice(-2)

    this.element.value = this._group(intPart) + "," + decPart
  }

  _group(n) {
    return n.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  }
}
