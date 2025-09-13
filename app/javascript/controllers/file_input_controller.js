// app/javascript/controllers/file_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "name", "button"]

  connect() { this.update() }
  change()  { this.update() }

  update() {
    const files = this.inputTarget?.files || []
    // Nome dos arquivos em PT-BR
    this.nameTarget.textContent = files.length
      ? Array.from(files).map(f => f.name).join(", ")
      : "Nenhum arquivo selecionado"

    // Rótulo do botão sempre em PT-BR
    if (this.hasButtonTarget) this.buttonTarget.textContent = "Escolher arquivo"
  }
}
