import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { container: String } // id do container que recebe <turbo-stream action="append">

  connect() {
    // bind
    this._onSubmitStart = this._onSubmitStart.bind(this)
    this._onSubmitEnd   = this._onSubmitEnd.bind(this)
    this._onBeforeStreamRender = this._onBeforeStreamRender.bind(this)
    this._onNativeSubmit = this._onNativeSubmit.bind(this)

    // Se Turbo estiver habilitado (padrão), use os eventos do Turbo
    this.element.addEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.addEventListener("turbo:submit-end",   this._onSubmitEnd)

    // Fallback para forms com data-turbo="false"
    this.element.addEventListener("submit", this._onNativeSubmit)

    // escuta streams (append) e rola
    document.addEventListener("turbo:before-stream-render", this._onBeforeStreamRender)

    // ao abrir a tela, rola para o fim
    requestAnimationFrame(() => this._scrollDown())
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.removeEventListener("turbo:submit-end",   this._onSubmitEnd)
    this.element.removeEventListener("submit", this._onNativeSubmit)
    document.removeEventListener("turbo:before-stream-render", this._onBeforeStreamRender)
  }

  // ---------- helpers ----------
  _submitButton() {
    // prioriza um botão dentro do form; funciona com <button> ou <input type="submit">
    return this.element.querySelector("[type='submit']")
  }
  _disable(btn) {
    if (!btn) return
    btn.disabled = true
    btn.setAttribute("aria-busy", "true")
    btn.classList.add("is-submitting")
  }
  _enable(btn) {
    if (!btn) return
    btn.disabled = false
    btn.removeAttribute("aria-busy")
    btn.classList.remove("is-submitting")
  }

  // ---------- Turbo (data-turbo !== false) ----------
  _onSubmitStart() {
    this._disable(this._submitButton())
  }

  _onSubmitEnd(evt) {
    // reabilita sempre
    this._enable(this._submitButton())

    // sucesso?
    const ok =
      evt?.detail?.fetchResponse?.succeeded ??
      evt?.detail?.success ??
      (evt?.detail?.fetchResponse?.response?.status >= 200 &&
       evt?.detail?.fetchResponse?.response?.status < 300)

    if (ok) {
      const textarea = this.element.querySelector("textarea")
      if (textarea) {
        textarea.value = ""
        textarea.style.height = ""
      }
      this._scrollDown()
    }
  }

  // ---------- Fallback (data-turbo="false") ----------
  _onNativeSubmit(e) {
    // evita múltiplos envios em forms sem Turbo
    const btn = this._submitButton()
    this._disable(btn)
    // se for navegação normal, o reenable não é necessário (vai trocar de página).
    // se houver prevenção noutro handler e o submit não acontecer, reabilite em um tick:
    setTimeout(() => {
      if (!this.element.matches(":invalid") && !this.element.checkValidity?.()) return
      // se o submit foi cancelado por validação do browser, reabilite
      this._enable(btn)
    }, 0)
  }

  // ---------- turbo-stream append -> rolar até o fim ----------
  _onBeforeStreamRender(evt) {
    const stream   = evt.target
    const action   = stream.getAttribute("action")
    const targetId = stream.getAttribute("target")

    if (action === "append" && targetId === this.containerValue) {
      // espera aplicar o append pra rolar
      requestAnimationFrame(() => {
        requestAnimationFrame(() => this._scrollDown())
      })
    }
  }

  _scrollDown() {
    const id  = this.hasContainerValue ? this.containerValue : null
    const box = id ? document.getElementById(id) : null

    // 1) se a área de mensagens for scrollável, rola nela
    if (box && typeof box.scrollTo === "function" && box.scrollHeight > box.clientHeight) {
      box.scrollTo({ top: box.scrollHeight, behavior: "smooth" })
      return
    }

    // 2) fallback: rola a página até a última msg
    const safeId = id ? id.replace(/([ #.;+*~':"!^$[\]()=>|/@])/g, "\\$1") : ""
    const lastMsg = document.querySelector(safeId ? `#${safeId} .msg:last-child` : ".msg:last-child")
    lastMsg?.scrollIntoView({ behavior: "smooth", block: "end" })
  }
}
