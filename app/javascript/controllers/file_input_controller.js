// app/javascript/controllers/file_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "name", "button", "preview", "placeholder", "fallback"]
  static values = {
    previewSelector: String,
    placeholderSelector: String,
    fallbackSelector: String
  }

  connect() {
    this._objectURL = null
    this.update()
  }

  disconnect() {
    if (this._objectURL) URL.revokeObjectURL(this._objectURL)
  }

  change() {
    this.update()
    this.updatePreview()
  }

  update() {
    const files = this.inputTarget?.files || []
    if (this.hasNameTarget) {
      this.nameTarget.textContent = files.length
        ? Array.from(files).map(f => f.name).join(", ")
        : "Nenhum arquivo selecionado"
    }
    if (this.hasButtonTarget) this.buttonTarget.textContent = "Escolher arquivo"
  }

  updatePreview() {
    const file = this.inputTarget?.files?.[0]

    const previewEl =
      (this.hasPreviewTarget ? this.previewTarget : null) ||
      (this.hasPreviewSelectorValue ? document.querySelector(this.previewSelectorValue) : null)

    const placeholderEl =
      (this.hasPlaceholderTarget ? this.placeholderTarget : null) ||
      (this.hasPlaceholderSelectorValue ? document.querySelector(this.placeholderSelectorValue) : null)

    const fallbackEl =
      (this.hasFallbackTarget ? this.fallbackTarget : null) ||
      (this.hasFallbackSelectorValue ? document.querySelector(this.fallbackSelectorValue) : null)

    // Sem arquivo: restaura UI
    if (!file) {
      if (this._objectURL) { URL.revokeObjectURL(this._objectURL); this._objectURL = null }
      if (previewEl) previewEl.classList.add("d-none")
      if (placeholderEl) placeholderEl.classList.remove("d-none")
      if (fallbackEl)     fallbackEl.classList.remove("d-none")
      return
    }

    // Só pré-visualiza imagens
    if (file.type && !file.type.startsWith("image/")) return

    // Gera URL temporária de preview
    if (this._objectURL) URL.revokeObjectURL(this._objectURL)
    this._objectURL = URL.createObjectURL(file)

    if (previewEl) {
      // Se for <img>, define src; senão, usa background-image
      if (previewEl.tagName === "IMG") {
        previewEl.src = this._objectURL
        if (!previewEl.style.objectFit) previewEl.style.objectFit = "cover"
      } else {
        previewEl.style.backgroundImage = `url("${this._objectURL}")`
        previewEl.style.backgroundSize = "cover"
        previewEl.style.backgroundPosition = "center"
      }
      previewEl.classList.remove("d-none")
    }

    if (placeholderEl) placeholderEl.classList.add("d-none")
    if (fallbackEl)     fallbackEl.classList.add("d-none")
  }
}
