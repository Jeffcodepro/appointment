import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    serviceId: Number
  }
  static targets = ["modal", "date", "slots", "submit", "startAt", "endAt"]

  connect() {
    // data inicial = hoje
    const today = new Date().toISOString().slice(0,10)
    this.dateTarget.value = this.dateTarget.value || today
    this.fetchSlots()
  }

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.add("show")
    this.modalTarget.style.display = "block"
  }

  close() {
    this.modalTarget.classList.remove("show")
    this.modalTarget.style.display = "none"
    // limpa seleção
    this.startAtTarget.value = ""
    this.endAtTarget.value   = ""
    this.submitTarget.disabled = true
  }

  changeDate() {
    this.fetchSlots()
  }

  fetchSlots() {
    const date = this.dateTarget.value
    const url = `/services/${this.serviceIdValue}/availability?date=${encodeURIComponent(date)}&t=${Date.now()}`
    this.slotsTarget.innerHTML = `<div class="text-muted small">Carregando…</div>`
    fetch(url)
      .then(r => r.json())
      .then(data => {
        if (!data.slots || data.slots.length === 0) {
          this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários livres neste dia.</div>`
          this.submitTarget.disabled = true
          return
        }
        this.slotsTarget.innerHTML = ""
        data.slots.forEach(s => {
          const btn = document.createElement("button")
          btn.type = "button"
          btn.className = "btn btn-outline-secondary btn-sm me-2 mb-2"
          btn.textContent = s.label
          btn.addEventListener("click", () => this.selectSlot(s))
          this.slotsTarget.appendChild(btn)
        })
      })
      .catch(() => {
        this.slotsTarget.innerHTML = `<div class="text-danger small">Erro ao carregar horários.</div>`
      })
  }

  selectSlot(s) {
    // marca visualmente
    Array.from(this.slotsTarget.querySelectorAll("button")).forEach(b => b.classList.remove("active"))
    const btn = Array.from(this.slotsTarget.querySelectorAll("button")).find(b => b.textContent === s.label)
    if (btn) btn.classList.add("active")

    // salva hidden fields
    this.startAtTarget.value = s.start_at
    this.endAtTarget.value   = s.end_at
    this.submitTarget.disabled = false
  }
}
