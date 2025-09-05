// app/javascript/controllers/history_filters_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "status", "query", "startDate", "endDate", "dateDropdown"]
  static values  = { resetUrl: String }

  connect() {
    this.onChange = this.onChange.bind(this)
    this.onSubmit = this.onSubmit.bind(this)
    this.onDocClick = this.onDocClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)

    this.element.addEventListener("change", this.onChange)
    this.element.addEventListener("submit", this.onSubmit)
    document.addEventListener("click", this.onDocClick)
    document.addEventListener("keydown", this.onKeydown)

    if (this.hasQueryTarget) {
      this.onQueryInput = this._debounce(() => this._markScrollAndVisit(), 400)
      this.queryTarget.addEventListener("input", this.onQueryInput)
    }
    if (this.hasStartDateTarget) {
      this.startDateTarget.addEventListener("input", this.onChange)
    }
    if (this.hasEndDateTarget) {
      this.endDateTarget.addEventListener("input", this.onChange)
    }

    this._syncActivePresetFromInputs()

    try {
      if (sessionStorage.getItem("scrollToResults") === "1") {
        sessionStorage.removeItem("scrollToResults")
        document.getElementById("results")?.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    } catch (_) {}
  }

  disconnect() {
    this.element.removeEventListener("change", this.onChange)
    this.element.removeEventListener("submit", this.onSubmit)
    document.removeEventListener("click", this.onDocClick)
    document.removeEventListener("keydown", this.onKeydown)
    if (this.onQueryInput && this.hasQueryTarget) {
      this.queryTarget.removeEventListener("input", this.onQueryInput)
    }
  }

  // ===== UI: dropdown de datas =====
  toggleDateDropdown(e) {
    e.preventDefault()
    const open = this._dropdownOpen()
    this._setDropdownOpen(!open)
  }
  onDocClick(e) {
    if (!this._dropdownOpen()) return
    const menu = this.dateDropdownTarget
    const toggle = this.element.querySelector(".date-dropdown__toggle")
    if (menu.contains(e.target) || toggle.contains(e.target)) return
    this._setDropdownOpen(false)
  }
  onKeydown(e) {
    if (e.key === "Escape" && this._dropdownOpen()) {
      this._setDropdownOpen(false)
    }
  }
  _dropdownOpen() {
    return this.hasDateDropdownTarget && this.dateDropdownTarget.classList.contains("is-open")
  }
  _setDropdownOpen(open) {
    if (!this.hasDateDropdownTarget) return
    this.dateDropdownTarget.classList.toggle("is-open", open)
    this.dateDropdownTarget.setAttribute("aria-hidden", open ? "false" : "true")
    const toggle = this.element.querySelector(".date-dropdown__toggle")
    if (toggle) toggle.setAttribute("aria-expanded", open ? "true" : "false")
  }

  // ===== eventos do form =====
  onChange(e) {
    // se mexeu dentro do dropdown, não aplicar imediatamente (custom range usa "Aplicar")
    if (e.target.closest(".date-dropdown__menu")) return
    if (e?.target?.dataset?.action === "history-filters#resetFilters") return
    this._markScrollAndVisit()
  }

  onSubmit(e) {
    e.preventDefault()
    this._markScrollAndVisit()
  }

  // ===== presets & custom =====
  applyPreset(e) {
    const preset = e.currentTarget?.dataset?.preset
    if (!preset) return
    const { start, end } = this._computePresetRange(preset)
    if (this.hasStartDateTarget) this.startDateTarget.value = start
    if (this.hasEndDateTarget)   this.endDateTarget.value   = end
    this._updateActivePreset(preset)
    this._setDropdownOpen(false)
    this._markScrollAndVisit()
  }

  applyCustomRange() {
    // valida: se só um lado preenchido, não aplica
    const s = this.hasStartDateTarget ? this.startDateTarget.value : ""
    const e = this.hasEndDateTarget   ? this.endDateTarget.value   : ""
    if ((s && !e) || (!s && e)) return
    this._updateActivePreset("") // custom
    this._setDropdownOpen(false)
    this._markScrollAndVisit()
  }

  clearCustomRange() {
    if (this.hasStartDateTarget) this.startDateTarget.value = ""
    if (this.hasEndDateTarget)   this.endDateTarget.value   = ""
    this._updateActivePreset("")
  }

  resetFilters() {
    // limpa inputs
    if (this.hasQueryTarget)     this.queryTarget.value = ""
    if (this.hasRoleTarget)      this.roleTarget.value  = "all"
    if (this.hasStatusTarget)    this.statusTarget.value= ""
    if (this.hasStartDateTarget) this.startDateTarget.value = ""
    if (this.hasEndDateTarget)   this.endDateTarget.value   = ""

    // UI: sem preset ativo e fecha dropdown
    this._updateActivePreset("")
    this._setDropdownOpen(false)

    // mantém o auto-scroll para a lista
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}

    // navega para /history SEM parâmetros → controller mostra tudo
    const base = this.hasResetUrlValue ? this.resetUrlValue : this._baseAction()
    const url  = `${base}#results`
    window.Turbo?.visit ? Turbo.visit(url, { action: "replace" }) : window.location.assign(url)
  }

  // ===== navegação =====
  _markScrollAndVisit() {
    try { sessionStorage.setItem("scrollToResults", "1") } catch (_) {}

    const fd = new FormData(this.element)
    const params = new URLSearchParams()
    for (const [k, v] of fd.entries()) {
      if (v !== null && String(v).trim() !== "") params.append(k, String(v))
    }

    const base = this._baseAction()
    const url  = params.toString() ? `${base}?${params.toString()}#results` : `${base}#results`
    window.Turbo?.visit ? Turbo.visit(url, { action: "advance" }) : window.location.assign(url)
  }

  _baseAction() { return this.element.action.split("?")[0].split("#")[0] }

  // ===== presets helpers =====
  _computePresetRange(preset) {
    const today = new Date()
    const ymd = (d) => {
      const y = d.getFullYear()
      const m = String(d.getMonth() + 1).padStart(2, "0")
      const da = String(d.getDate()).padStart(2, "0")
      return `${y}-${m}-${da}`
    }
    const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())

    let start, end
    switch (preset) {
      case "today": {
        const t = startOfDay(today)
        start = t; end = t; break
      }
      case "yesterday": {
        const y = startOfDay(new Date(today)); y.setDate(y.getDate() - 1)
        start = y; end = y; break
      }
      case "last7": {
        const s = startOfDay(new Date(today)); s.setDate(s.getDate() - 6)
        start = s; end = startOfDay(today); break
      }
      case "last30": {
        const s = startOfDay(new Date(today)); s.setDate(s.getDate() - 29)
        start = s; end = startOfDay(today); break
      }
      case "last90": {
        const s = startOfDay(new Date(today)); s.setDate(s.getDate() - 89)
        start = s; end = startOfDay(today); break
      }
      case "thisMonth": {
        const s = new Date(today.getFullYear(), today.getMonth(), 1)
        const e = new Date(today.getFullYear(), today.getMonth() + 1, 0)
        start = s; end = e; break
      }
      case "lastMonth": {
        const s = new Date(today.getFullYear(), today.getMonth() - 1, 1)
        const e = new Date(today.getFullYear(), today.getMonth(), 0)
        start = s; end = e; break
      }
      default: {
        start = this.hasStartDateTarget && this.startDateTarget.value ? new Date(this.startDateTarget.value) : startOfDay(today)
        end   = this.hasEndDateTarget   && this.endDateTarget.value   ? new Date(this.endDateTarget.value)   : startOfDay(today)
      }
    }
    return { start: ymd(start), end: ymd(end) }
  }

  _syncActivePresetFromInputs() {
    if (!this.hasStartDateTarget || !this.hasEndDateTarget) return
    const s = this.startDateTarget.value, e = this.endDateTarget.value
    const same = (ps, pe) => (s === ps && e === pe)
    const r = ["today","yesterday","last7","last30","last90","thisMonth","lastMonth"]
      .map(p => [p, this._computePresetRange(p)])
    const hit = r.find(([p, rge]) => same(rge.start, rge.end))
    this._updateActivePreset(hit ? hit[0] : "")
  }

  _updateActivePreset(preset) {
    this.element.querySelectorAll('[data-preset]').forEach(btn => {
      const active = btn.dataset.preset === preset && preset !== ""
      btn.classList.toggle("is-active", active)
      btn.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  // utils
  _debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn.apply(this, a), ms) } }
}
