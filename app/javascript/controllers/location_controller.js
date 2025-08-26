// app/javascript/controllers/location_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "city", "category"]
  static values = { selectedCity: String, resetUrl: String }

  connect() {
    if (this.hasStateTarget)    this.stateTarget.addEventListener("change", this.onStateChange)
    if (this.hasCityTarget)     this.cityTarget.addEventListener("change", this.onCityChange)
    if (this.hasCategoryTarget) this.categoryTarget.addEventListener("change", this.onCategoryChange)

    // Intercepta o submit da lupa/Enter
    this.element.addEventListener("submit", this.onFormSubmit)

    // Carrega a lista de cidades (usa selectedCityValue vindo dos params via data-*)
    this.updateCities()
  }

  disconnect() {
    if (this.hasStateTarget)    this.stateTarget.removeEventListener("change", this.onStateChange)
    if (this.hasCityTarget)     this.cityTarget.removeEventListener("change", this.onCityChange)
    if (this.hasCategoryTarget) this.categoryTarget.removeEventListener("change", this.onCategoryChange)

    this.element.removeEventListener("submit", this.onFormSubmit) // <- remover, não adicionar
  }

  // ===== Handlers =====
  onFormSubmit = (e) => {
    e.preventDefault()
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}
    this.visitWithParams()
  }

  onStateChange = () => {
    this.selectedCityValue = ""       // limpa cidade ao trocar estado
    this.updateCities()
    setTimeout(() => { this.cityTarget?.focus() }, 0)
  }

  onCityChange = () => {
    this.selectedCityValue = this.cityTarget.value || ""
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}
    this.visitWithParams()
  }

  onCategoryChange = () => {
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}
    this.visitWithParams()
  }

  // ===== Cidades =====
  updateCities() {
    const state = this.stateTarget?.value || ""
    const url = state
      ? `/services/cities?state=${encodeURIComponent(state)}&t=${Date.now()}`
      : `/services/cities?t=${Date.now()}`

    fetch(url)
      .then(r => r.json())
      .then(cities => this.populateCityDropdown(cities))
      .catch(err => console.error("Erro ao buscar cidades:", err))
  }

  clearCityDropdown() {
    if (!this.hasCityTarget) return
    this.cityTarget.innerHTML = '<option value="">Todas as Cidades</option>'
  }

  populateCityDropdown(cities) {
    if (!this.hasCityTarget) return
    const wanted = (this.selectedCityValue || "").trim()

    this.clearCityDropdown()
    let hasMatch = false
    cities.forEach(city => {
      const opt = document.createElement("option")
      opt.value = city
      opt.text = city
      if (wanted && this._normalize(city) === this._normalize(wanted)) {
        opt.selected = true
        hasMatch = true
      }
      this.cityTarget.appendChild(opt)
    })

    if (hasMatch) {
      const exact = Array.from(this.cityTarget.options)
        .find(o => this._normalize(o.value) === this._normalize(wanted))
      if (exact) this.cityTarget.value = exact.value
    }
  }

  // ===== Navegação com Turbo =====
  visitWithParams() {
    const form = this.element
    if (!form) return

    const fd = new FormData(form)
    const params = new URLSearchParams()
    for (const [k, v] of fd.entries()) {
      if (v !== null && String(v).trim() !== "") params.append(k, String(v))
    }

    const base = form.action.split("#")[0]
    const url  = params.toString()
      ? `${base}?${params.toString()}#results`
      : `${base}#results`

    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(url, { action: "advance" })
    } else {
      window.location.assign(url)
    }
  }

  // ===== Reset =====
  resetFilters = () => {
    const q = this.element.querySelector('input[name="query"]')
    if (q) q.value = ''
    if (this.hasCategoryTarget) this.categoryTarget.value = ''
    if (this.hasStateTarget)    this.stateTarget.value = ''
    if (this.hasCityTarget)     this.cityTarget.innerHTML = '<option value="">Todas as Cidades</option>'
    this.selectedCityValue = ""

    // ✅ marca que devemos rolar até #results após a navegação
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}

    const baseUrl = this.hasResetUrlValue ? this.resetUrlValue : this.element.action.split('?')[0].split('#')[0]
    const url = `${baseUrl}#results`

    if (window.Turbo?.visit) window.Turbo.visit(url, { action: "replace" })
    else window.location.assign(url)
  }

  // ===== util =====
  _normalize(str) {
    return (str || "")
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
  }
}
