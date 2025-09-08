// app/javascript/controllers/service_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["category", "subcategory", "price", "hours", "total"];
  static values  = { subcats: Object };

  connect() {
    this.refreshSubcategories();
    this.updateTotal();
  }

  onCategoryChange() {
    this.refreshSubcategories();
  }

  recalc() {
    this.updateTotal();
  }

  // ===== helpers =====
  refreshSubcategories() {
    const cat = this.hasCategoryTarget ? (this.categoryTarget.value || "") : "";
    const options = (this.subcatsValue && this.subcatsValue[cat]) || [];
    const selectedHint = this.hasSubcategoryTarget
      ? (this.subcategoryTarget.dataset.selected || this.subcategoryTarget.value || "")
      : "";

    if (!this.hasSubcategoryTarget) return;

    const frag = document.createDocumentFragment();

    // blank
    const blank = document.createElement("option");
    blank.value = "";
    blank.textContent = "Selecione a subcategoria";
    frag.appendChild(blank);

    // options
    options.forEach(opt => {
      const o = document.createElement("option");
      o.value = opt;
      o.textContent = opt;
      if (opt === selectedHint) o.selected = true;
      frag.appendChild(o);
    });

    this.subcategoryTarget.innerHTML = "";
    this.subcategoryTarget.appendChild(frag);
  }

  updateTotal() {
    const price = this.parseBRL(this.hasPriceTarget ? this.priceTarget.value : "");
    const hrs   = this.parseBRL(this.hasHoursTarget ? this.hoursTarget.value : "");
    const total = (price || 0) * (hrs || 0);
    if (this.hasTotalTarget) this.totalTarget.textContent = this.formatBRL(total);
  }

  parseBRL(str) {
    if (!str) return 0;
    // aceita "150", "150,50", "R$ 150,50", e ignora separadores de milhar com ponto
    const cleaned    = String(str).replace(/[^\d,.-]/g, "").replace(/\.(?=\d{3}(?:\D|$))/g, "");
    const normalized = cleaned.replace(",", ".");
    const n = parseFloat(normalized);
    return Number.isNaN(n) ? 0 : n;
  }

  formatBRL(n) {
    try {
      return Number(n).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
    } catch {
      const v = (Math.round(Number(n) * 100) / 100).toFixed(2).replace(".", ",");
      return `R$ ${v}`;
    }
  }
}
