// app/javascript/controllers/prevent_multi_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { container: String }

  connect() {
    this._onSubmitStart = this._onSubmitStart.bind(this)
    this._onSubmitEnd   = this._onSubmitEnd.bind(this)
    this._onBeforeStreamRender = this._onBeforeStreamRender.bind(this)

    this.element.addEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.addEventListener("turbo:submit-end",   this._onSubmitEnd)

    // escuta streams (append) e rola
    document.addEventListener("turbo:before-stream-render", this._onBeforeStreamRender)

    // ao abrir a tela, rola para o fim
    requestAnimationFrame(() => this._scrollDown())
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this._onSubmitStart)
    this.element.removeEventListener("turbo:submit-end",   this._onSubmitEnd)
    document.removeEventListener("turbo:before-stream-render", this._onBeforeStreamRender)
  }

  _onSubmitStart() {
    const btn = this.element.querySelector("[type='submit']")
    if (btn) btn.disabled = true
  }

  _onSubmitEnd(evt) {
    const btn = this.element.querySelector("[type='submit']")
    if (btn) btn.disabled = false

    // checagem mais robusta de sucesso
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
