// app/javascript/controllers/location_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "city", "category"]
  static values = { selectedCity: String, resetUrl: String }

  connect() {
    this.element.setAttribute("data-turbo", "false")

    if (this.hasStateTarget)    this.stateTarget.addEventListener("change", this.onStateChange)
    if (this.hasCityTarget)     this.cityTarget.addEventListener("change", this.onCityChange)
    if (this.hasCategoryTarget) this.categoryTarget.addEventListener("change", this.onCategoryChange)

    // Intercepta o submit da lupa/Enter
    this.element.addEventListener("submit", this.onFormSubmit, { capture: true })

    // back/forward mantém a UX suave
    this._onPopState = () => this.swapResultsAndMarkersFrom(window.location.href)
    window.addEventListener("popstate", this._onPopState)

    // Carrega a lista de cidades (usa selectedCityValue vindo dos params via data-*)
    this.updateCities()
  }

  disconnect() {
    if (this.hasStateTarget)    this.stateTarget.removeEventListener("change", this.onStateChange)
    if (this.hasCityTarget)     this.cityTarget.removeEventListener("change", this.onCityChange)
    if (this.hasCategoryTarget) this.categoryTarget.removeEventListener("change", this.onCategoryChange)

    this.element.removeEventListener("submit", this.onFormSubmit, { capture: true })
    window.removeEventListener("popstate", this._onPopState)
  }

  // ===== Handlers =====
  onFormSubmit = (e) => {
    e.preventDefault()
    e.stopPropagation()
    e.stopImmediatePropagation()
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

  // ===== Navegação SUAVE =====
  async visitWithParams() {
    const form = this.element
    const fd = new FormData(form)
    const params = new URLSearchParams()
    for (const [k, v] of fd.entries()) {
      if (v !== null && String(v).trim() !== "") params.append(k, String(v))
    }
    const base = form.action.split("#")[0]
    const url  = params.toString() ? `${base}?${params.toString()}#results` : `${base}#results`
    await this.swapResultsAndMarkersFrom(url)
  }

  async resetFilters() {
    const q = this.element.querySelector('input[name="query"]')
    if (q) q.value = ''
    if (this.hasCategoryTarget) this.categoryTarget.value = ''
    if (this.hasStateTarget)    this.stateTarget.value = ''
    if (this.hasCityTarget)     this.cityTarget.innerHTML = '<option value="">Todas as Cidades</option>'
    this.selectedCityValue = ""
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}

    const baseUrl = this.hasResetUrlValue ? this.resetUrlValue : this.element.action.split('?')[0].split('#')[0]
    const url = `${baseUrl}#results`
    await this.swapResultsAndMarkersFrom(url)
  }

  // Faz fetch da página e troca #results e markers do mapa
  async swapResultsAndMarkersFrom(url) {
    try {
      const res = await fetch(url, { headers: { Accept: "text/html" } })
      if (!res.ok) throw new Error("bad response")
      const html = await res.text()
      const doc  = new DOMParser().parseFromString(html, "text/html")

      // 1) swap de #results
      const newResults = doc.querySelector("#results")
      const curResults = document.querySelector("#results")
      if (newResults && curResults) curResults.replaceWith(newResults)

      // 2) sincroniza markers no mapa permanente
      const incomingMap = doc.querySelector("#services-map")
      const existingMap = document.querySelector("#services-map")
      if (incomingMap && existingMap) {
        const newMarkers = incomingMap.getAttribute("data-map-markers-value")
        if (newMarkers) existingMap.setAttribute("data-map-markers-value", newMarkers)
      }

      // 3) atualiza URL + scroll suave
      window.history.pushState({}, "", url)
      document.querySelector("#results")?.scrollIntoView({ behavior: "smooth", block: "start" })
    } catch (e) {
      console.error(e)
      // fallback seguro
      if (window.Turbo?.visit) window.Turbo.visit(url, { action: "advance" })
      else window.location.assign(url)
    }
  }

  // ===== util =====
  _normalize(str) {
    return (str || "")
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
  }
}
