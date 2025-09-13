// app/javascript/controllers/map_controller.js
import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = {
    apiKey: String,
    markers: Array,
    spiderRadii: Object,
    clickablePins: Boolean
  }

  connect() {
    console.log("MapController v2.7 loaded")
    mapboxgl.accessToken = this.apiKeyValue

    try { this.element.replaceChildren() } catch { this.element.innerHTML = "" }

    const h = parseFloat(getComputedStyle(this.element).height)
    if (!(h > 0)) this.element.style.height = "420px"
    this.element.style.width = this.element.style.width || "100%"
    this.element.classList.remove("is-ready")

    // index/show: se não vier, deduz pelo id
    this._isIndex = this.hasClickablePinsValue ? this.clickablePinsValue : (this.element.id === "services-map")

    const initial = this._loadViewState() || this._initialFromMarkers() || { center: [-46.6333, -23.55], zoom: 9 }

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v12",
      projection: "mercator",
      fadeDuration: 0,
      center: initial.center,
      zoom: initial.zoom,
      attributionControl: true
    })

    // coleções
    this.groups     = new Map()
    this.anchors    = new Map()
    this.spiderfied = new Map()
    this.allMarkers = []
    this.allLegs    = []
    this._viewInitialized = false

    this.map.on("load", () => {
      this._renderAllMarkers()
      this.map.resize()
      this.element.classList.add("is-ready")
      this._viewInitialized = true
    })

    this._onMoveEnd = () => this._saveViewState()
    this._onZoomEnd = () => this._saveViewState()
    this._onMove    = () => this._repositionSpiderfied()
    this._onZoom    = () => this._repositionSpiderfied()
    this._onClick   = () => this._collapseAllSpiderfied()

    this.map.on("moveend", this._onMoveEnd)
    this.map.on("zoomend", this._onZoomEnd)
    this.map.on("move",    this._onMove)
    this.map.on("zoom",    this._onZoom)
    this.map.on("click",   this._onClick)

    // turbo permanent sync
    this._syncPermanent = (ev) => {
      const incoming = ev.detail.newBody?.querySelector("#services-map")
      if (!incoming) return
      const newMarkers = incoming.getAttribute("data-map-markers-value")
      const newApiKey  = incoming.getAttribute("data-map-api-key-value")

      if (newApiKey && newApiKey !== this.element.getAttribute("data-map-api-key-value")) {
        this.element.setAttribute("data-map-api-key-value", newApiKey)
      }
      if (newMarkers && newMarkers !== this.element.getAttribute("data-map-markers-value")) {
        this.element.setAttribute("data-map-markers-value", newMarkers)
      }
    }
    document.addEventListener("turbo:before-render", this._syncPermanent)

    this._onResize = () => { try { this.map?.resize() } catch (_) {} }
    window.addEventListener("resize", this._onResize)
    document.addEventListener("turbo:load", this._onResize)
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this._syncPermanent)
    window.removeEventListener("resize", this._onResize)
    document.removeEventListener("turbo:load", this._onResize)
    try {
      this.map?.off("moveend", this._onMoveEnd)
      this.map?.off("zoomend", this._onZoomEnd)
      this.map?.off("move", this._onMove)
      this.map?.off("zoom", this._onZoom)
      this.map?.off("click", this._onClick)
    } catch (_) {}
    this._clearAllMarkers()
    try { this.map?.remove() } catch(_) {}
    this.map = null
  }

  // ------- reatividade dos markers -------
  markersValueChanged() {
    if (!this.map) return
    const animate = this._viewInitialized
    if (this.map.loaded()) this._renderAllMarkers(animate)
    else this.map.once("load", () => this._renderAllMarkers(animate))
  }

  // ---------- state ----------
  _saveViewState() {
    if (!this.map || this.element.id !== "services-map") return
    const c = this.map.getCenter()
    const z = this.map.getZoom()
    try { sessionStorage.setItem("servicesMapView", JSON.stringify({ center: [c.lng, c.lat], zoom: z })) } catch(_) {}
  }
  _loadViewState() {
    if (this.element.id !== "services-map") return null
    try {
      const raw = sessionStorage.getItem("servicesMapView")
      return raw ? JSON.parse(raw) : null
    } catch(_) { return null }
  }
  _initialFromMarkers() {
    const list = this._markersArray()
    if (!list.length) return null
    const avg = list.reduce((a, m) => ({ lat: a.lat + m.lat, lng: a.lng + m.lng }), { lat: 0, lng: 0 })
    const center = [avg.lng / list.length, avg.lat / list.length]
    return { center, zoom: list.length > 1 ? 11 : 13 }
  }

  // ---------- pipeline ----------
  _renderAllMarkers(animate = false) {
    this._clearAllMarkers()
    this._groupMarkersByCoordinate()
    this._addGroupedMarkers()
    this._fitMapToMarkers(animate)
  }

  _clearAllMarkers() {
    this._collapseAllSpiderfied()
    this.allMarkers.forEach(m => { try { m.remove() } catch(_) {} })
    this.allMarkers = []
    this.allLegs.forEach(l => { try { l.remove() } catch(_) {} })
    this.allLegs = []
    this.groups.clear()
    this.anchors.clear()
  }

  _markersArray() {
    let list = this.markersValue
    if (typeof list === "string") {
      try { list = JSON.parse(list) } catch { list = [] }
    }
    return Array.isArray(list) ? list : []
  }

  _groupMarkersByCoordinate() {
    this.groups.clear()
    const list = this._markersArray()
    list.forEach(m => {
      if (typeof m.lat !== "number" || typeof m.lng !== "number") return
      const key = `${m.lat},${m.lng}`
      if (!this.groups.has(key)) this.groups.set(key, [])
      this.groups.get(key).push(m)
    })
  }

  _addGroupedMarkers() {
    const isIndex = this._isIndex

    this.groups.forEach((items, key) => {
      const [lat, lng] = key.split(",").map(Number)

      if (items.length === 1) {
        const m  = items[0]
        const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id, { clickable: isIndex })
        const mk = new mapboxgl.Marker({ element: el }).setLngLat([lng, lat])
        mk.addTo(this.map)
        this._attachHoverTip(mk, m)
        this._attachDetailToggle(mk, m)
        this.allMarkers.push(mk)
      } else {
        const el = this._buildClusterMarker(items.length)
        const anchor = new mapboxgl.Marker({ element: el }).setLngLat([lng, lat]).addTo(this.map)
        this.allMarkers.push(anchor)
        this.anchors.set(key, { marker: anchor, el })
        el.addEventListener("click", (ev) => {
          ev.stopPropagation()
          if (this.spiderfied.has(key)) this._collapseSpiderfied(key)
          else this._spiderfy(key, items)
        })
      }
    })
  }

  // ------------ clique no pin: smooth update de #results, sem reload ------------
  async _smoothFilterTo(serviceId, url) {
    try {
      const res = await fetch(url, { headers: { Accept: "text/html" } })
      if (!res.ok) throw new Error("bad response")
      const html = await res.text()
      const doc = new DOMParser().parseFromString(html, "text/html")

      // 1) substitui os cards (#results)
      const newResults = doc.querySelector("#results")
      const currentResults = document.querySelector("#results")
      if (newResults && currentResults) currentResults.replaceWith(newResults)

      // 2) sincroniza markers do mapa
      const incomingMap = doc.querySelector("#services-map")
      const existingMap = document.querySelector("#services-map")
      if (incomingMap && existingMap) {
        const newMarkers = incomingMap.getAttribute("data-map-markers-value")
        if (newMarkers) existingMap.setAttribute("data-map-markers-value", newMarkers)
      }

      // 3) atualiza URL e rola suave
      window.history.pushState({}, "", url)
      const target = document.querySelector("#results")
      if (target) target.scrollIntoView({ behavior: "smooth", block: "start" })
    } catch (_) {
      if (window.Turbo?.visit) window.Turbo.visit(url, { action: "advance" })
      else window.location.assign(url)
    }
  }

  _navigateToService(serviceId) {
    // filtrar no index (comportamento do chip de preço)
    const path = window.location.pathname.split("?")[0].split("#")[0]
    const base = /^\/services\/\d+/.test(path) ? "/services" : path
    const filterUrl = `${base}?service_id=${encodeURIComponent(serviceId)}#results`
    this._smoothFilterTo(serviceId, filterUrl)
  }

  // ---------- builders ----------
  _buildPriceMarker(priceText, title, url, serviceId, opts = {}) {
    const clickable = !!opts.clickable
    const el = document.createElement("div")
    el.className = "price-marker"
    el.innerText = priceText || "•"
    el.title = "" // desativa tooltip nativo
    el.setAttribute("aria-label", `${title || "Serviço"} por ${this._priceLabel(priceText)}`)

    if (clickable) {
      el.setAttribute("role", "button")
      el.setAttribute("tabindex", "0")
      el.style.cursor = "pointer"

      const onNav = (e) => {
        e.stopPropagation()
        this._navigateToService(serviceId)
      }

      el.addEventListener("click", onNav)
      el.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onNav(e) }
      })
    } else {
      el.style.cursor = "default"
      el.setAttribute("aria-disabled", "true")
    }

    return el
  }

  _buildClusterMarker(count) {
    const el = document.createElement("div")
    el.className = "cluster-marker"
    el.innerText = String(count)
    el.title = `${count} serviços neste endereço`
    return el
  }

  // ---------- spiderfy ----------
  _spiderfy(key, items) {
    if (this.spiderfied.has(key)) return
    const [lat, lng] = key.split(",").map(Number)
    const center = new mapboxgl.LngLat(lng, lat)
    const isIndex = this._isIndex

    const children = []
    const lines = []
    const radiusPx = this._spiderRadius(items.length)

    items.forEach((m, i) => {
      const target = this._offsetLngLatByPixels(center, radiusPx, this._angleForIndex(i, items.length))
      const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id, { clickable: isIndex })
      const child = new mapboxgl.Marker({ element: el }).setLngLat(target).addTo(this.map)
      this._attachHoverTip(child, m)
      this._attachDetailToggle(child, m)
      children.push(child)

      const leg = this._buildRadialLine(center, target)
      if (leg) lines.push(leg)
    })

    const anchor = this.anchors.get(key)
    if (anchor) anchor.el.classList.add("cluster-open")

    this.spiderfied.set(key, { children, lines, center, radiusPx, count: items.length })
  }

  _collapseSpiderfied(key) {
    const data = this.spiderfied.get(key)
    if (!data) return
    data.children.forEach(m => { try { m.remove() } catch(_) {} })
    data.lines.forEach(l => { try { l.remove() } catch(_) {} })
    this.spiderfied.delete(key)
    const anchor = this.anchors.get(key)
    if (anchor) anchor.el.classList.remove("cluster-open")
  }

  _collapseAllSpiderfied() {
    Array.from(this.spiderfied.keys()).forEach(k => this._collapseSpiderfied(k))
  }

  // raio configurável via data-map-spider-value
  _spiderRadius(n) {
    if (this.hasSpiderRadiiValue) {
      const map = this.spiderRadiiValue || {}
      const thresholds = Object.keys(map)
        .filter(k => k !== "*")
        .map(k => parseInt(k, 10))
        .filter(Number.isFinite)
        .sort((a, b) => a - b)

      for (const t of thresholds) {
        if (n <= t) return Number(map[t]) || 0
      }
      if (map["*"] != null) return Number(map["*"]) || 0
      if (thresholds.length) return Number(map[String(thresholds[thresholds.length - 1])]) || 0
      return this._defaultSpiderRadius(n)
    }
    return this._defaultSpiderRadius(n)
  }

  _defaultSpiderRadius(n) {
    if (n <= 4)  return 60
    if (n <= 8)  return 80
    if (n <= 12) return 100
    return 120
  }

  _angleForIndex(i,total){ const off=15; return (i*(360/total))-90+off }
  _offsetLngLatByPixels(center,r,deg){
    const p=this.map.project(center); const rad=(deg*Math.PI)/180
    return this.map.unproject({x:p.x+r*Math.cos(rad), y:p.y+r*Math.sin(rad)})
  }

  _repositionSpiderfied() {
    this.spiderfied.forEach((data, key) => {
      const [lat, lng] = key.split(",").map(Number)
      const center = new mapboxgl.LngLat(lng, lat)
      data.center = center
      data.children.forEach((marker, i) => {
        const newLL = this._offsetLngLatByPixels(center, data.radiusPx, this._angleForIndex(i, data.count))
        marker.setLngLat(newLL)
      })
      data.lines.forEach(l => { try { l.remove() } catch(_) {} })
      data.lines.length = 0
      data.children.forEach((marker) => {
        const newLine = this._buildRadialLine(center, marker.getLngLat())
        if (newLine) data.lines.push(newLine)
      })
    })
  }

  _buildRadialLine(fromLngLat, toLngLat) {
    const from = this.map.project(fromLngLat)
    const to   = this.map.project(toLngLat)
    const length = Math.hypot(to.x - from.x, to.y - from.y)
    if (length < 4) return null
    const angleRad = Math.atan2(to.y - from.y, to.x - from.x)
    const angleDeg = (angleRad * 180) / Math.PI

    const el = document.createElement("div")
    el.className = "spider-leg"
    el.style.width = `${length}px`
    el.style.transform = `rotate(${angleDeg}deg)`
    el.style.transformOrigin = "left center"
    el.style.pointerEvents = "none"

    const mid = this.map.unproject({ x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 })
    const leg = new mapboxgl.Marker({ element: el, anchor: "center" }).setLngLat(mid).addTo(this.map)
    this.allLegs.push(leg)
    return leg
  }

  // ---------- helpers ----------
  _priceLabel(price) {
    if (price == null) return "—"
    if (typeof price === "string") return price
    try {
      return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(price)
    } catch(_) {
      const n = Number(price)
      return Number.isFinite(n) ? `R$ ${n.toFixed(2)}` : String(price)
    }
  }

  // escapa HTML básico
  _esc(s) {
    return String(s ?? "").replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
  }

  _categoryText(d) {
    const c = d.categories ?? d.category
    if (Array.isArray(c)) return c.map(s => String(s||"").trim()).filter(Boolean).join(" • ")
    if (typeof c === "string") return c
    return ""
  }

  // Hover “tip” (maior e legível)
  _hoverTipHTML(d) {
    const name = (d.label || d.name || "Serviço").toString()
    return `
      <div class="hover-tip">
        <div class="ht-title">${this._esc(name)}</div>
      </div>
    `
  }
  _attachHoverTip(markerInstance, data) {
    const map = this.map
    const popup = new mapboxgl.Popup({
      closeButton: false,
      closeOnClick: false,
      offset: 12,
      className: "hover-tip-popup"
    })
    let hideTimer = null
    const show = () => {
      try {
        clearTimeout(hideTimer)
        popup
          .setLngLat(markerInstance.getLngLat())
          .setHTML(this._hoverTipHTML(data))
          .addTo(map)
        const el = popup.getElement()
        if (el && !el._hoverBound) {
          el.addEventListener("mouseenter", () => clearTimeout(hideTimer))
          el.addEventListener("mouseleave", () => {
            hideTimer = setTimeout(() => { try { popup.remove() } catch(_) {} }, 120)
          })
          el._hoverBound = true
        }
      } catch(_) {}
    }
    const hide = () => {
      clearTimeout(hideTimer)
      hideTimer = setTimeout(() => { try { popup.remove() } catch(_) {} }, 120)
    }
    const el = markerInstance.getElement()
    el.addEventListener("mouseenter", show)
    el.addEventListener("mouseleave", hide)
    el.addEventListener("touchstart", show, { passive: true })
    el.addEventListener("touchend", hide,   { passive: true })
  }

  // Card detalhado — mostra apenas categoria, valor e "Ver detalhes"
  _detailHTML(d) {
    const name  = (d.label || d.name || "Serviço").toString()
    const price = this._priceLabel(d.price)
    const cat   = this._categoryText(d)

    return `
      <div class="detail-card">
        <div class="dc-header">
          <div class="dc-title">${this._esc(name)}</div>
          <div class="dc-price">${price}</div>
        </div>
        <div class="dc-meta">
          ${cat ? `<div class="dc-row"><span class="dc-k">Categoria:</span> <span class="dc-v">${this._esc(cat)}</span></div>` : ""}
        </div>
        <div class="dc-actions">
          <button type="button" class="dc-action-btn" data-url="${d.url || ""}">Ver detalhes</button>
        </div>
      </div>
    `
  }

  _bindDetailPopupActions(popup, onAfterClose) {
    const root = popup.getElement()
    if (!root) return
    const btn = root.querySelector(".dc-action-btn")
    if (!btn) return

    const handler = (e) => {
      e.preventDefault()
      e.stopPropagation()
      const url = btn.getAttribute("data-url")
      try { popup.remove() } catch(_) {}
      if (typeof onAfterClose === "function") onAfterClose()

      // ⛳️ Ir para o SHOW do serviço (mesma aba)
      if (url) {
        if (window.Turbo?.visit) window.Turbo.visit(url, { action: "advance" })
        else window.location.assign(url)
      }
    }
    btn.addEventListener("click", handler, { once: true })
  }

  _attachDetailToggle(markerInstance, data) {
    const map = this.map
    const chip = markerInstance.getElement()
    chip.classList.add("price-marker-flex")

    // botão setinha
    const arrow = document.createElement("button")
    arrow.type = "button"
    arrow.className = "pm-arrow"
    arrow.setAttribute("aria-label", "Mais informações")
    arrow.innerHTML = "▾"
    chip.appendChild(arrow)

    const popup = new mapboxgl.Popup({
      closeButton: true,
      closeOnClick: true,
      offset: { bottom: [0, 16], top: [0, 16], left: [0, 16], right: [0, 16] },
      anchor: "bottom",
      className: "detail-popup"
    })

    let open = false
    let onMoveFn = null

    const syncClosedState = () => {
      open = false
      arrow.classList.remove("open")
      if (onMoveFn) { map.off("move", onMoveFn); onMoveFn = null }
    }

    const toggle = (ev) => {
      ev.stopPropagation()
      ev.preventDefault()

      if (open) {
        try { popup.remove() } catch (_) {}
        syncClosedState()
        return
      }

      try {
        popup
          .setLngLat(markerInstance.getLngLat())
          .setHTML(this._detailHTML(data))
          .addTo(map)

        open = true
        arrow.classList.add("open")

        // fecha ao mover o mapa
        onMoveFn = () => { try { popup.remove() } catch (_) {}; syncClosedState() }
        map.on("move", onMoveFn)

        // fecha pelo X / clique fora
        popup.once("close", syncClosedState)
        popup.once("remove", syncClosedState)

        // botão "Ver detalhes" -> SHOW do serviço
        this._bindDetailPopupActions(popup, syncClosedState)
      } catch(_) {}
    }

    arrow.addEventListener("click", toggle)
  }

  // ---------- view ----------
  _fitMapToMarkers(animate=false) {
    const bounds = new mapboxgl.LngLatBounds()
    let hasAny = false
    this.groups.forEach((_, key) => {
      const [lat, lng] = key.split(",").map(Number)
      bounds.extend([lng, lat]); hasAny = true
    })
    if (!hasAny) return
    this.map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: animate ? 400 : 0 })
  }
}
