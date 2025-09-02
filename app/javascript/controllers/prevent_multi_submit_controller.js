import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:submit-start", () => {
      const btn = this.element.querySelector("[type='submit']")
      if (btn) btn.disabled = true
    })
    this.element.addEventListener("turbo:submit-end", () => {
      const btn = this.element.querySelector("[type='submit']")
      if (btn) btn.disabled = false
      const textarea = this.element.querySelector("textarea")
      if (textarea) textarea.value = ""
    })
  }
}
