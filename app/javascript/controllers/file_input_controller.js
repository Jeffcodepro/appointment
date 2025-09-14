import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "name", "button", "preview", "placeholder", "fallback"]
  static values = {
    previewSelector: String,      // CSS selector para achar o <img> de preview fora do bloco
    placeholderSelector: String,  // CSS selector p/ placeholder fora do bloco
    fallbackSelector: String      // CSS selector p/ fallback (iniciais) fora do bloco
  }

  connect() {
    this._objectURL = null
    this.update() // atualiza o label do botão / nome do arquivo
  }

  disconnect() {
    if (this._objectURL) URL.revokeObjectURL(this._objectURL)
  }

  change(event) {
    this.update()
    this.updatePreview(event)
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

  updatePreview(event) {
    const file = this.inputTarget?.files?.[0]
    if (!file) return

    // Libera URL anterior, se houver
    if (this._objectURL) URL.revokeObjectURL(this._objectURL)
    this._objectURL = URL.createObjectURL(file)

    // Encontra elementos de preview/placeholder/fallback
    const previewEl =
      (this.hasPreviewTarget ? this.previewTarget : null) ||
      (this.hasPreviewSelectorValue ? document.querySelector(this.previewSelectorValue) : null)

    const placeholderEl =
      (this.hasPlaceholderTarget ? this.placeholderTarget : null) ||
      (this.hasPlaceholderSelectorValue ? document.querySelector(this.placeholderSelectorValue) : null)

    const fallbackEl =
      (this.hasFallbackTarget ? this.fallbackTarget : null) ||
      (this.hasFallbackSelectorValue ? document.querySelector(this.fallbackSelectorValue) : null)

    // Aplica preview
    if (previewEl) {
      previewEl.src = this._objectURL
      previewEl.classList.remove("d-none")
      // Se não tiver dimensões via CSS, garante cover básico:
      previewEl.style.objectFit ||= "cover"
    }

    // Some com placeholder/fallback se existirem
    if (placeholderEl) placeholderEl.classList.add("d-none")
    if (fallbackEl)     fallbackEl.classList.add("d-none")
  }
}
