// app/javascript/controllers/roles_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["client", "pro", "activeRole", "proBlock"]

  connect() { this.sync() }

  toggle(event) {
    this.enforceAtLeastOne(event)
    this.sync()
  }

  enforceAtLeastOne(event) {
    if (!this.clientTarget.checked && !this.proTarget.checked) {
      event.target.checked = true
    }
  }

  sync() {
    if (this.hasActiveRoleTarget) {
      this.activeRoleTarget.value =
        (this.proTarget.checked && !this.clientTarget.checked) ? "professional" : "client"
    }
    if (this.hasProBlockTarget) {
      if (this.proTarget.checked) {
        this.proBlockTarget.classList.remove("is-hidden")
        this.requireProFields(true)
      } else {
        this.proBlockTarget.classList.add("is-hidden")
        this.requireProFields(false)
      }
    }
  }

  requireProFields(on) {
    if (!this.hasProBlockTarget) return
    const fields = this.proBlockTarget.querySelectorAll("[data-pro-required]")
    fields.forEach((el) => on ? el.setAttribute("required", "required") : el.removeAttribute("required"))
  }
}
