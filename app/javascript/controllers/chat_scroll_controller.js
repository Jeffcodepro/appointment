// app/javascript/controllers/chat_scroll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["anchor"]   // sentinela no fim da lista

  connect() {
    this._scrollDown = this._scrollDown.bind(this)
    this._onBeforeStreamRender = this._onBeforeStreamRender.bind(this)
    this._onPageShow = (e) => { if (e.persisted) this._scrollDown() }

    // primeira carga + microticks (garante altura final)
    requestAnimationFrame(this._scrollDown)
    setTimeout(this._scrollDown, 0)
    setTimeout(this._scrollDown, 60)

    document.addEventListener("turbo:load", this._scrollDown)
    window.addEventListener("load", this._scrollDown)
    window.addEventListener("pageshow", this._onPageShow)

    // novos nós (turbo partial render)
    this._observer = new MutationObserver((list) => {
      for (const m of list) {
        if (m.type === "childList" && (m.addedNodes?.length || m.removedNodes?.length)) {
          requestAnimationFrame(this._scrollDown)
          break
        }
      }
    })
    this._observer.observe(this.element, { childList: true, subtree: false })

    // mudanças de altura (imagens, fontes)
    this._resizeObs = new ResizeObserver(() => this._scrollDown())
    this._resizeObs.observe(this.element)

    // APPENDs turbo-stream direcionados a este container
    document.addEventListener("turbo:before-stream-render", this._onBeforeStreamRender)
  }

  disconnect() {
    this._observer?.disconnect()
    this._resizeObs?.disconnect()
    document.removeEventListener("turbo:load", this._scrollDown)
    window.removeEventListener("load", this._scrollDown)
    window.removeEventListener("pageshow", this._onPageShow)
    document.removeEventListener("turbo:before-stream-render", this._onBeforeStreamRender)
  }

  _onBeforeStreamRender(evt) {
    const s = evt.target
    if (s?.getAttribute("action") === "append" && s.getAttribute("target") === this.element.id) {
      requestAnimationFrame(() => requestAnimationFrame(this._scrollDown))
    }
  }

  _scrollDown() {
    const box = this.element
    if (!box) return

    // tenta rolar o container em si
    box.scrollTop = box.scrollHeight

    // rola até o sentinela (faz o ancestral rolável correto rolar)
    this.anchorTarget?.scrollIntoView({ behavior: "auto", block: "end" })

    // reforço pós-layout
    setTimeout(() => {
      box.scrollTop = box.scrollHeight
      this.anchorTarget?.scrollIntoView({ behavior: "auto", block: "end" })
    }, 80)
  }
}
