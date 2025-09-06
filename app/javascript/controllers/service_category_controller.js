import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "subcategory", "price", "avg", "previewTotal"]
  static values = { subcategories: Object }

  connect() {
    this.populateSubcategories()
    this.recalc()
  }

  categoryChanged() { this.populateSubcategories() }

  populateSubcategories() {
    const category = this.hasCategoryTarget ? this.categoryTarget.value : ""
    const list = (this.subcategoriesValue || {})[category] || []
    const select = this.subcategoryTarget
    if (!select) return

    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = list.length ? "Selecione uma subcategoria" : "Selecione uma categoria primeiro"
    select.appendChild(blank)

    list.forEach(item => {
      const opt = document.createElement("option")
      opt.value = item
      opt.textContent = item
      select.appendChild(opt)
    })

    select.disabled = list.length === 0
  }

  recalc() {
    const raw = (this.hasPriceTarget ? this.priceTarget.value : "") || ""
    const price = parseFloat(raw.replace(/\./g, "").replace(",", ".")) || 0
    const avg = parseInt(this.hasAvgTarget ? this.avgTarget.value : "0", 10) || 0
    const total = price * avg

    if (this.hasPreviewTotalTarget) {
      this.previewTotalTarget.textContent = total.toLocaleString("pt-BR", {
        style: "currency", currency: "BRL"
      })
    }
  }
}
