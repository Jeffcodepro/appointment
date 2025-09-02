import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { serviceId: Number, loggedIn: Boolean }
  static targets = ["modal", "slots", "submit", "startAt", "endAt", "pickedDateLabel"]


  connect() {
    this._ensureServiceId();
    this._onCalendarFrameLoad = this._onCalendarFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this._onCalendarFrameLoad)

    // 🔒 garante estado fechado no mount
    this._forceCloseModalAndReset();

    // fecha também em qualquer carregamento turbo
    this._onTurboLoad = () => this._forceCloseModalAndReset();
    document.addEventListener("turbo:load", this._onTurboLoad);

    // fecha quando a página é restaurada do bfcache
    this._onPageShow = (evt) => { if (evt.persisted) this._forceCloseModalAndReset() }
    window.addEventListener("pageshow", this._onPageShow);

    document.documentElement.classList.remove("custom-modal-open")

    this._onVisit = () => document.documentElement.classList.remove("custom-modal-open")
    window.addEventListener("turbo:visit", this._onVisit)

    this._onBeforeCache = () => { this._forceCloseModalAndReset() }
    document.addEventListener("turbo:before-cache", this._onBeforeCache)

    this._slotsAbortController = null;
    this._slotsReqId = 0;
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this._onCalendarFrameLoad)
    window.removeEventListener("turbo:visit", this._onVisit)
    document.removeEventListener("turbo:before-cache", this._onBeforeCache)
    document.removeEventListener("turbo:load", this._onTurboLoad)
    window.removeEventListener("pageshow", this._onPageShow)
    document.documentElement.classList.remove("custom-modal-open")
  }

  openClick(e) {
    e.preventDefault()
    this._openFresh()
  }

  submit(e) {
    if (!this._isLoggedIn()) {
      e.preventDefault()
      const back = location.pathname + location.search
      const to   = `/users/sign_in?return_to=${encodeURIComponent(back)}`

      this._forceCloseModalAndReset()

      // 👇 limpa snapshots do Turbo antes de sair
      try { window.Turbo?.session?.clearCache?.() } catch (_) {}

      window.location.assign(to)
      return
    }
    // logado → envio normal
  }

  _isLoggedIn() {
    return !!this.hasLoggedInValue && this.loggedInValue === true
  }

  _openFresh() {
    this._forceCloseModalAndReset()
    this._currentDate = new Date().toISOString().slice(0,10)
    this._updatePickedLabel()
    this._openModal()
    this.fetchSlots()

    const frame = document.getElementById("calendar_frame")
    if (frame) {
      this._bindDayClicks(frame)
      this._markPastDays(frame) // NEW: marca passados logo de cara

      // NEW: se já está carregado, pinta fully-booked imediatamente
      const days = Array.from(frame.querySelectorAll(".day[data-date]"))
      if (days.length) {
        const counts = new Map()
        days.forEach(el => {
          const d = el.dataset.date
          if (!d) return
          const ym = d.slice(0,7) // YYYY-MM
          counts.set(ym, (counts.get(ym) || 0) + 1)
        })
        if (counts.size) {
          const shownYM = Array.from(counts.entries()).sort((a,b)=>b[1]-a[1])[0][0]
          this._fetchMonthSummary(frame, shownYM)
        }
      }
    }
  }

  _forceCloseModalAndReset() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("is-open")
      this.modalTarget.setAttribute("aria-hidden", "true")
      this.modalTarget.hidden = true 
    }
    document.documentElement.classList.remove("custom-modal-open")
    if (this.hasStartAtTarget) this.startAtTarget.value = ""
    if (this.hasEndAtTarget)   this.endAtTarget.value   = ""
    if (this.hasSubmitTarget)  this.submitTarget.disabled = true
    if (this.hasSlotsTarget)   this.slotsTarget.innerHTML = ""
    this.modalOpen = false
  }

  close() {
    this._closeModal()
    this.startAtTarget.value = ""
    this.endAtTarget.value   = ""
    this.submitTarget.disabled = true
  }

  onBackdrop(e) {
    if (e.target.classList.contains("custom-modal__overlay")) this.close()
  }

  onKeydown(e) {
    if (!this.modalOpen) return
    if (e.key === "Escape") {
      e.preventDefault(); this.close()
    } else if (e.key === "Tab") {
      const focusables = this._focusableElements()
      if (focusables.length === 0) return
      const i = focusables.indexOf(document.activeElement)
      const next = e.shiftKey ? (i <= 0 ? focusables.length - 1 : i - 1)
                              : (i === focusables.length - 1 ? 0 : i + 1)
      e.preventDefault()
      focusables[next].focus()
    }
  }

  pickDate(e) {
    const el = e.currentTarget
    if (el.classList.contains('past') || el.classList.contains('weekend')) return;

    const date = el?.dataset.date
    if (!date || el.classList.contains("past")) return;
    this.submitTarget.disabled = true   // ⬅️ garante desabilitado ao trocar o dia
    this.startAtTarget.value = ""
    this.endAtTarget.value   = ""

    this._applySelectedClass(el)
    this._currentDate = date
    this._updatePickedLabel()
    this.fetchSlots()
  }

  // ===== FETCH SLOTS =====
  fetchSlots() {
    const sid = this._fetchServiceIdOrFail();
    if (sid == null) return;

    const date = this._currentDate || new Date().toISOString().slice(0,10);
    this._currentDate = date;

    const today = new Date(); today.setHours(0,0,0,0);
    const selected = new Date(date + "T00:00:00");
    if (selected < today) {
      this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários livres neste dia.</div>`;
      this.submitTarget.disabled = true;
      return;
    }


    if (this._slotsAbortController) this._slotsAbortController.abort();
    this._slotsAbortController = new AbortController();

    const reqId = ++this._slotsReqId;
    const expectedDate = date;

    this.slotsTarget.innerHTML = `<div class="text-muted small">Carregando…</div>`;


    const url = `/services/${sid}/availability.json?date=${encodeURIComponent(date)}&t=${Date.now()}`;

    fetch(url, {
        headers: { "Accept": "application/json" },
        signal: this._slotsAbortController.signal
      })
        .then(async (r) => {
          if (!r.ok) {
            const body = await r.text();
            console.error("availability error", r.status, body);
            throw new Error(`HTTP ${r.status}`);
          }
          return r.json();
        })
        .then(data => {
          // DESCARTA resposta obsoleta ou de outra data
          if (reqId !== this._slotsReqId) return;
          if ((data?.date || expectedDate) !== expectedDate) return;
          if (expectedDate !== this._currentDate) return;

          this.slotsTarget.innerHTML = "";
          this.submitTarget.disabled = true;

          if (!data.slots || data.slots.length === 0) {
            this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários livres neste dia.</div>`;
            return;
          }

          let hasAvailable = false;

          data.slots.forEach(s => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "btn btn-outline-secondary btn-sm me-2 mb-2";
            btn.textContent = s.label;

            if (s.available) {
              hasAvailable = true;
              btn.addEventListener("click", () => this.selectSlot(s, btn));
            } else {
              btn.disabled = true;
              btn.setAttribute("aria-disabled", "true");
              btn.title = "Horário indisponível";
            }

            this.slotsTarget.appendChild(btn);
          });

          if (!hasAvailable) {
            const note = document.createElement("div");
            note.className = "text-muted small w-100";
            note.textContent = "Sem horários livres neste dia.";
            this.slotsTarget.appendChild(note);
          }
        })
        .catch((err) => {
          if (err?.name === "AbortError") return; // requisição cancelada → ignore
          this.slotsTarget.innerHTML = `<div class="text-danger small">Erro ao carregar horários.</div>`;
        });
    }

  selectSlot(s, btnEl) {
    Array.from(this.slotsTarget.querySelectorAll("button")).forEach(b => b.classList.remove("active"))
    if (btnEl) btnEl.classList.add("active")
    this.startAtTarget.value = s.start_at
    this.endAtTarget.value   = s.end_at
    this.submitTarget.disabled = false
  }

  _updatePickedLabel() {
    if (!this.hasPickedDateLabelTarget) return;

    const d = this._currentDate;
    if (!d) {                       // nada selecionado ainda
      this.pickedDateLabelTarget.textContent = "";
      return;
    }

    const parts = String(d).split("-");
    if (parts.length !== 3) {       // fallback se vier em outro formato
      this.pickedDateLabelTarget.textContent = String(d);
      return;
    }

    const [y, m, day] = parts;
    this.pickedDateLabelTarget.textContent = `${day}/${m}/${y}`;
  }


  // ===== MODAL (PURO CSS/JS) =====
  _openModal() {
    if (!this.hasModalTarget) return
    this.modalTarget.hidden = false
    this.modalTarget.classList.add("is-open")
    this.modalTarget.setAttribute("aria-hidden", "false")
    document.documentElement.classList.add("custom-modal-open")
    this.modalOpen = true
    this._rememberedFocus = document.activeElement
    const first = this._focusableElements()[0]
    if (first) first.focus()
  }

  _closeModal() {
    if (!this.hasModalTarget) return
    this.modalTarget.classList.remove("is-open")
    this.modalTarget.setAttribute("aria-hidden", "true")
    this.modalTarget.hidden = true                      // 👈 esconde
    document.documentElement.classList.remove("custom-modal-open")
    this.modalOpen = false
    if (this._rememberedFocus?.focus) this._rememberedFocus.focus()
  }

  _focusableElements() {
    const dialog = this.modalTarget.querySelector(".custom-modal__dialog")
    if (!dialog) return []
    return Array.from(
      dialog.querySelectorAll('a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])')
    )
  }

  // ===== Quando o calendário troca de mês via Turbo =====
  _onCalendarFrameLoad(e) {
    const frame = e.target
    if (!(frame && frame.id === "calendar_frame")) return
    if (!this.modalOpen) return

    this._bindDayClicks(frame)
    this._markPastDays(frame)                 // NEW: marca dias passados

    // Descobre mês dominante mostrado (já existia)
    const days = Array.from(frame.querySelectorAll(".day"))
    if (days.length === 0) return
    const counts = new Map()
    days.forEach(el => {
      const dateStr = el.dataset.date
      if (!dateStr) return
      const ym = dateStr.slice(0, 7) // YYYY-MM
      counts.set(ym, (counts.get(ym) || 0) + 1)
    })
    if (counts.size === 0) return
    const shownYM = Array.from(counts.entries()).sort((a,b) => b[1]-a[1])[0][0]

    // NEW: pinta dias esgotados daquele mês
    this._fetchMonthSummary(frame, shownYM).then(() => {
      // Seleciona automaticamente o 1º dia útil NÃO esgotado; se não houver, pega o 1º dia útil
      const firstAvailable = days
        .filter(el => el.dataset.date?.startsWith(shownYM))
        .find(el => !el.classList.contains("weekend")
                 && !el.classList.contains("past")
                 && !el.classList.contains("fully-booked"))

      const pick = firstAvailable ||
                  days.filter(el => el.dataset.date?.startsWith(shownYM))
                      .find(el => !el.classList.contains("weekend")
                                && !el.classList.contains("past"));

      if (pick?.dataset.date) {
        this._applySelectedClass(pick)
        this._currentDate = pick.dataset.date
        this._updatePickedLabel()
        this.fetchSlots()
      } else {
        this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários deste mês.</div>`
        this.submitTarget.disabled = true
      }
    })
  }


  // ===== Helpers p/ clique em dias dentro do frame =====
  _bindDayClicks(frameEl) {
    // evita listeners duplicados
    if (this._boundDayClicks) return;
    this._boundDayClicks = true;

    frameEl.addEventListener("click", (evt) => {
      const el = evt.target.closest(".day[data-date]");
      if (!el) return;

      // bloqueia passado/fim de semana (continua podendo clicar em fully-booked)
      if (el.classList.contains("past") || el.classList.contains("weekend")) return;

      evt.preventDefault();
      this._applySelectedClass(el);
      this._currentDate = el.dataset.date;
      this._updatePickedLabel();
      this.fetchSlots();
    });
  }

  // NEW: marca .past client-side (comparação YYYY-MM-DD é lexicográfica)
  _markPastDays(frameEl) {
    const today = new Date(); today.setHours(0,0,0,0);
    frameEl.querySelectorAll(".day").forEach(el => {
      const d = el.dataset.date; if (!d) return;
      const dObj = new Date(d + "T00:00:00");
      if (dObj < today) el.classList.add("past"); else el.classList.remove("past");
    });
  }

  // NEW: busca resumo do mês e marca .fully-booked (continua clicável)
  async _fetchMonthSummary(frameEl, ym) {
    const monthDays = Array.from(frameEl.querySelectorAll(`.day[data-date^="${ym}"]`));
    if (monthDays.length === 0) return;

    const sorted = monthDays.map(el => el.dataset.date).sort(); // YYYY-MM-DD
    const start = sorted[0], end = sorted[sorted.length - 1];

    const url = `/services/${this.serviceIdValue}/availability_summary.json?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}&t=${Date.now()}`;

    try {
      const r = await fetch(url, { headers: { "Accept": "application/json" } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);

      const data = await r.json();
      const set = new Set(data?.fully_booked || []);

      monthDays.forEach(el => {
        const d = el.dataset.date;
        if (!d) return;

        if (set.has(d)) {
          el.classList.add("fully-booked");
          el.setAttribute("title", "Sem horário livre");
          el.setAttribute("aria-label", `${d} sem horário livre`);
        } else {
          el.classList.remove("fully-booked");
          el.removeAttribute("title");
          el.removeAttribute("aria-label");
        }
      });
    } catch (e) {
      console.warn("availability_summary error", e);
    }
  }


  _applySelectedClass(el) {
    const frame = document.getElementById("calendar_frame")
    if (frame) frame.querySelectorAll(".day.selected").forEach(d => d.classList.remove("selected"))
    el.classList.add("selected")
  }

  _ensureServiceId() {
    // se já veio via data-*, ok
    if (this.hasServiceIdValue && Number.isFinite(this.serviceIdValue)) return;

    // tenta pegar do hidden do form (já existe no modal)
    const hidden = document.getElementById("service_id");
    const fromHidden = hidden ? parseInt(hidden.value, 10) : NaN;
    if (Number.isFinite(fromHidden)) {
      this.serviceIdValue = fromHidden;
      return;
    }

    // tenta subir no DOM por segurança
    const wrapper = this.element.closest("[data-schedules-service-id-value]");
    if (wrapper) {
      const v = parseInt(wrapper.getAttribute("data-schedules-service-id-value"), 10);
      if (Number.isFinite(v)) {
        this.serviceIdValue = v;
        return;
      }
    }

    console.error("[schedules] serviceId ausente");
  }

  _fetchServiceIdOrFail() {
    if (!this.hasServiceIdValue || !Number.isFinite(this.serviceIdValue)) {
      if (this.hasSlotsTarget) {
        this.slotsTarget.innerHTML = `<div class="text-danger small">Erro: serviço não informado.</div>`;
      }
      return null;
    }
    return this.serviceIdValue;
  }

}
