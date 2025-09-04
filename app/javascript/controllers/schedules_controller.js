import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    serviceId: Number,
    loggedIn: Boolean,
    openHour:  Number,
    closeHour: Number,
  }
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
          // DESCARTA resposta obsoleta/fora de data
          if (reqId !== this._slotsReqId) return;
          if ((data?.date || expectedDate) !== expectedDate) return;
          if (expectedDate !== this._currentDate) return;

          this.slotsTarget.innerHTML = "";
          this.submitTarget.disabled = true;

          const now = new Date();
          const isToday = expectedDate === now.toISOString().slice(0,10);

          // defensivo: mostra só disponíveis e, se hoje, somente depois de agora
          let slots = Array.isArray(data.slots) ? data.slots : [];
          slots = slots.filter(s => {
            if (!s.available) return false;
            if (!isToday) return true;
            const start = new Date(s.start_at);
            return start > now;
          });

          if (slots.length === 0) {
            this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários livres neste dia.</div>`;
            return;
          }

          // Renderiza APENAS slots clicáveis
          slots.forEach(s => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "btn btn-outline-secondary btn-sm me-2 mb-2";
            btn.textContent = s.label;
            btn.addEventListener("click", () => this.selectSlot(s, btn));
            this.slotsTarget.appendChild(btn);
          });
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
    const frame = e.target;
    if (!(frame && frame.id === "calendar_frame")) return;
    if (!this.modalOpen) return;

    // rebinds & marca passados
    this._bindDayClicks(frame);
    this._markPastDays(frame);

    // 1) pega mês “dominante” exibido
    const shownYM = this._dominantMonth(frame); // "YYYY-MM"
    if (!shownYM) return;

    // 2) escolhe imediatamente o primeiro dia útil não-passado (ignora fully-booked por enquanto)
    const firstPick = this._firstWorkingSelectableDay(frame, shownYM);
    if (firstPick?.dataset.date) {
      this._applySelectedClass(firstPick);
      this._currentDate = firstPick.dataset.date;
      this._updatePickedLabel();   // 👈 atualiza o badge imediatamente
      this.fetchSlots();           // carrega slots desse novo dia
    } else {
      // nenhum dia útil → limpa slots/label
      this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários deste mês.</div>`;
      this.submitTarget.disabled = true;
      this._currentDate = null;
      this._updatePickedLabel();
    }

    // 3) pinta os dias “esgotados” e, se o escolhido ficou fully-booked, troca por outro
    this._fetchMonthSummary(frame, shownYM).then(() => {
      if (!this._currentDate) return;

      const selectedEl = frame.querySelector(`.day.selected[data-date="${this._currentDate}"]`);
      if (selectedEl?.classList.contains("fully-booked")) {
        const alt = this._firstWorkingSelectableDay(frame, shownYM, { requireFree: true });
        if (alt?.dataset.date) {
          this._applySelectedClass(alt);
          this._currentDate = alt.dataset.date;
          this._updatePickedLabel();  // 👈 garante badge correto após pintar fully-booked
          this.fetchSlots();
        } else {
          this.slotsTarget.innerHTML = `<div class="text-muted small">Sem horários livres neste mês.</div>`;
          this.submitTarget.disabled = true;
        }
      }
    });
  }

  _dominantMonth(frameEl) {
    const days = Array.from(frameEl.querySelectorAll(".day[data-date]"));
    if (!days.length) return null;
    const count = new Map();
    days.forEach(el => {
      const d = el.dataset.date; if (!d) return;
      const ym = d.slice(0, 7);
      count.set(ym, (count.get(ym) || 0) + 1);
    });
    return Array.from(count.entries()).sort((a,b)=>b[1]-a[1])[0]?.[0] || null;
  }

  _firstWorkingSelectableDay(frameEl, ym, options = {}) {
    const today = new Date(); today.setHours(0,0,0,0);
    const requireFree = !!options.requireFree;

    const candidates = Array.from(
      frameEl.querySelectorAll(`.day[data-date^="${ym}"]`)
    ).filter(el => {
      const d = el.dataset.date;
      if (!d) return false;

      // evita fim de semana e passado
      if (el.classList.contains("weekend")) return false;
      const dObj = new Date(d + "T00:00:00");
      if (dObj < today) return false;

      // se quiser só os livres (após pintar), evita fully-booked
      if (requireFree && el.classList.contains("fully-booked")) return false;

      return true;
    });

    // menor data primeiro (lexicográfico funciona em YYYY-MM-DD)
    candidates.sort((a, b) => a.dataset.date.localeCompare(b.dataset.date));
    return candidates[0] || null;
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
    const now   = new Date();

    // fallbacks caso não venha via data-*
    const openHour  = this.hasOpenHourValue  ? this.openHourValue  : 9;
    const closeHour = this.hasCloseHourValue ? this.closeHourValue : 18;

    frameEl.querySelectorAll(".day").forEach(el => {
      const d = el.dataset.date; if (!d) return;
      const dStart = new Date(d + "T00:00:00");
      const isPast = dStart < today;

      // se é hoje e já fechou, trata como passado
      const isClosedToday =
        dStart.getTime() === today.getTime() &&
        (now.getHours() > closeHour || (now.getHours() === closeHour && now.getMinutes() >= 0));

      if (isPast || isClosedToday) {
        el.classList.add("past");
      } else {
        el.classList.remove("past");
      }
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
