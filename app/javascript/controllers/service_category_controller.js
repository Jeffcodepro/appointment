// app/javascript/controllers/service_category_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "subcategory", "price", "avg", "previewTotal"]
  static values  = { subcategories: Object }

  connect() {
    this.populateSubcategories()
    this.recalc()
    this._maybeFocusSubtype()
  }

  categoryChanged() {
    this.populateSubcategories(true) // foca se houver opções
    this.recalc()
  }

  populateSubcategories(focusIfAny = false) {
    const category = this.hasCategoryTarget ? (this.categoryTarget.value || "") : ""
    const list     = (this.subcategoriesValue || {})[category] || []
    if (!this.hasSubcategoryTarget) return

    const select = this.subcategoryTarget
    const prev   = select.value

    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = list.length ? "Selecione um tipo de serviço" : "Selecione uma categoria primeiro"
    select.appendChild(blank)

    list.forEach(item => {
      const opt = document.createElement("option")
      opt.value = item
      opt.textContent = item
      select.appendChild(opt)
    })

    if (prev && list.includes(prev)) select.value = prev
    else select.value = ""

    select.disabled = list.length === 0
    if (focusIfAny && list.length > 0) select.focus()
  }

  recalc() {
    const raw  = (this.hasPriceTarget ? (this.priceTarget.value || "") : "")
    const avg  = this.hasAvgTarget ? parseInt(this.avgTarget.value || "0", 10) : 0
    const val  = this._parseBRL(raw)
    const total = (val || 0) * (avg || 0)

    if (this.hasPreviewTotalTarget) {
      this.previewTotalTarget.textContent = total.toLocaleString("pt-BR", {
        style: "currency", currency: "BRL"
      })
    }
  }

  _parseBRL(str) {
    if (!str) return 0
    const normalized = String(str).replace(/\./g, "").replace(",", ".")
    const n = parseFloat(normalized)
    return isNaN(n) ? 0 : n
  }

  _maybeFocusSubtype() {
    try {
      const p = new URLSearchParams(window.location.search)
      if (p.get("last_service_id") && this.hasSubcategoryTarget) this.subcategoryTarget.focus()
    } catch (_) {}
  }
}
