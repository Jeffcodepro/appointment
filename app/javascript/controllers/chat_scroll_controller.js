// app/javascript/controllers/chat_scroll_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._scrollDown = this._scrollDown.bind(this)
    this._onBeforeStreamRender = this._onBeforeStreamRender.bind(this)
    this._onPageShow = (e) => { if (e.persisted) this._scrollDown() }

    // 1º paint + microtick
    requestAnimationFrame(this._scrollDown)
    setTimeout(this._scrollDown, 0)

    document.addEventListener("turbo:load", this._scrollDown)
    window.addEventListener("load", this._scrollDown)
    window.addEventListener("pageshow", this._onPageShow)

    // mudanças na lista
    this._observer = new MutationObserver((list) => {
      for (const m of list) {
        if (m.type === "childList" && (m.addedNodes?.length || m.removedNodes?.length)) {
          requestAnimationFrame(this._scrollDown)
          break
        }
      }
    })
    this._observer.observe(this.element, { childList: true })

    // mudanças de altura (imagens, fontes, etc.)
    this._resizeObs = new ResizeObserver(() => this._scrollDown())
    this._resizeObs.observe(this.element)

    // APPEND turbo-stream com target = este container
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

  _scrollDown = () => {
    const el = this.element
    if (!el) return
    el.scrollTop = el.scrollHeight          // cola no fim
    setTimeout(() => { el.scrollTop = el.scrollHeight }, 50) // reforço
    el.querySelector(".msg:last-child")?.scrollIntoView({ behavior: "auto", block: "end" }) // fallback
  }
}
