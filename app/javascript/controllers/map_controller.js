// app/javascript/controllers/map_controller.js
import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  // spider: objeto JSON com breakpoints → ex.: {"4":70,"8":90,"12":110,"default":140}
  static values = { apiKey: String, markers: Array, spider: Object }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue

    // container vazio para evitar warning e overlay
    try { this.element.replaceChildren() } catch { this.element.innerHTML = "" }

    // respeita CSS; fallback se sem altura computada
    const h = parseFloat(getComputedStyle(this.element).height)
    if (!(h > 0)) this.element.style.height = "420px"
    this.element.style.width = this.element.style.width || "100%"
    this.element.classList.remove("is-ready")

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

    // eventos
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

    // sync de markers para o elemento permanente (index)
    this._syncPermanent = (ev) => {
      const incoming = ev.detail.newBody?.querySelector("#services-map")
      if (!incoming) return
      const newMarkers = incoming.getAttribute("data-map-markers-value")
      const newApiKey  = incoming.getAttribute("data-map-api-key-value")

      if (newApiKey && newApiKey !== this.element.getAttribute("data-map-api-key-value")) {
        this.element.setAttribute("data-map-api-key-value", newApiKey)
      }
      if (newMarkers && newMarkers !== this.element.getAttribute("data-map-markers-value")) {
        this.element.setAttribute("data-map-markers-value", newMarkers) // → dispara markersValueChanged()
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

  // dispara quando data-map-markers-value muda
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
    const isIndex = (this.element.id === "services-map")

    this.groups.forEach((items, key) => {
      const [lat, lng] = key.split(",").map(Number)

      if (items.length === 1) {
        const m  = items[0]
        const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id, { clickable: isIndex })
        const mk = new mapboxgl.Marker({ element: el }).setLngLat([lng, lat])
        mk.addTo(this.map)
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
      const newResults = doc.querySelector("#results")
      const currentResults = document.querySelector("#results")
      if (newResults && currentResults) {
        currentResults.replaceWith(newResults)
        // atualiza a URL (back/forward funcionam) e rola suave para o bloco
        window.history.pushState({}, "", url)
        newResults.scrollIntoView({ behavior: "smooth", block: "start" })
        return
      }
      // fallback: navegação turbo
      if (window.Turbo?.visit) window.Turbo.visit(url, { action: "advance" })
      else window.location.assign(url)
    } catch (_) {
      if (window.Turbo?.visit) window.Turbo.visit(url, { action: "advance" })
      else window.location.assign(url)
    }
  }

  _buildPriceMarker(priceText, title, url, serviceId, opts = {}) {
    const clickable = !!opts.clickable
    const el = document.createElement("div")
    el.className = "price-marker"
    el.innerText = priceText || "•"
    el.title = title || ""

    if (clickable) {
      el.setAttribute("role", "button")
      el.setAttribute("tabindex", "0")
      el.style.cursor = "pointer"

      const navigateToFiltered = () => {
        const path = window.location.pathname.split("?")[0].split("#")[0]
        const base = /^\/services\/\d+/.test(path) ? "/services" : path
        const filterUrl = `${base}?service_id=${encodeURIComponent(serviceId)}#results`

        // se estamos no INDEX, aplica filtro suave; no SHOW nem chega aqui (não-clickable)
        if (this.element.id === "services-map") {
          this._smoothFilterTo(serviceId, filterUrl)
        } else {
          // fallback teórico
          if (window.Turbo?.visit) window.Turbo.visit(filterUrl, { action: "advance" })
          else window.location.assign(filterUrl)
        }
      }

      el.addEventListener("click", (e) => {
        e.stopPropagation()
        if ((e.metaKey || e.ctrlKey) && url) { window.open(url, "_blank"); return }
        navigateToFiltered()
      })
      el.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); navigateToFiltered() }
      })
    } else {
      // SHOW: sem clique
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
    const isIndex = (this.element.id === "services-map")

    const children = []
    const lines = []
    const radiusPx = this._spiderRadius(items.length)

    items.forEach((m, i) => {
      const target = this._offsetLngLatByPixels(center, radiusPx, this._angleForIndex(i, items.length))
      const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id, { clickable: isIndex })
      const child = new mapboxgl.Marker({ element: el }).setLngLat(target).addTo(this.map)
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
  _spiderRadius(n){
    const cfg = this.spiderValue || null
    if (!cfg) { // defaults antigos
      if (n<=4) return 60
      if (n<=8) return 80
      if (n<=12) return 100
      return 120
    }
    // usa o menor breakpoint >= n; senão cai no default
    const entries = Object.entries(cfg)
      .filter(([k]) => k !== "default")
      .map(([k,v]) => [Number(k), Number(v)])
      .filter(([k,v]) => Number.isFinite(k) && Number.isFinite(v))
      .sort((a,b) => a[0]-b[0])

    for (const [thr, val] of entries) {
      if (n <= thr) return val
    }
    return Number(cfg.default) || 120
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
