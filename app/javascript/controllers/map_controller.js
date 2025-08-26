// app/javascript/controllers/map_controller.js
import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"

export default class extends Controller {
  static values = { apiKey: String, markers: Array }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue
    this.element.style.width  = this.element.style.width  || "100%"
    this.element.style.height = this.element.style.height || "100%"

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v10",
      attributionControl: true
    })

    // coleções para gerenciar limpeza/redesenho
    this.groups = new Map()
    this.anchors = new Map()
    this.spiderfied = new Map()
    this.allMarkers = []        // <-- âncoras e marcadores únicos
    this.allLegs = []           // <-- linhas do spiderfy (falha-safety extra)

    this.map.on("load", () => {
      this._renderAllMarkers()
      this.map.resize()
    })

    this.map.on("move", () => this._repositionSpiderfied())
    this.map.on("zoom", () => this._repositionSpiderfied())
    this.map.on("click", () => this._collapseAllSpiderfied())

    this._onResize = () => { try { this.map?.resize() } catch (_) {} }
    window.addEventListener("resize", this._onResize)
    document.addEventListener("turbo:load", this._onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
    document.removeEventListener("turbo:load", this._onResize)
    this._clearAllMarkers()
    try { this.map?.remove() } catch(_) {}
    this.map = null
  }

  // ✅ Reage quando data-map-markers-value muda (ex.: após reset)
  markersValueChanged() {
    if (!this.map) return
    if (this.map.loaded()) {
      this._renderAllMarkers()
    } else {
      this.map.once("load", () => this._renderAllMarkers())
    }
  }

  // ----- pipeline de render -----
  _renderAllMarkers() {
    this._clearAllMarkers()
    this._groupMarkersByCoordinate()
    this._addGroupedMarkers()
    this._fitMapToMarkers()
  }

  _clearAllMarkers() {
    // remove spiderfy aberto
    this._collapseAllSpiderfied()
    // remove âncoras e marcadores únicos
    this.allMarkers.forEach(m => { try { m.remove() } catch(_) {} })
    this.allMarkers = []
    // limpa mapas auxiliares
    this.groups.clear()
    this.anchors.clear()
  }

  // ----- Agrupa por coordenada -----
  _groupMarkersByCoordinate() {
    this.groups.clear()
    if (!Array.isArray(this.markersValue)) return
    this.markersValue.forEach(m => {
      const key = `${m.lat},${m.lng}`
      if (!this.groups.has(key)) this.groups.set(key, [])
      this.groups.get(key).push(m)
    })
  }

  _buildClusterMarker(count) {
  const el = document.createElement("div")
  el.className = "cluster-marker"
  el.innerText = String(count)
  el.title = `${count} serviços neste endereço`
  return el
  }

  // ----- Cria marcadores / clusters -----
  _addGroupedMarkers() {
    this.groups.forEach((items, key) => {
      const [lat, lng] = key.split(",").map(Number)

      if (items.length === 1) {
        const m = items[0]
        const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id)
        const popup = new mapboxgl.Popup().setHTML(m.info_window_html)
        const mk = new mapboxgl.Marker({ element: el })
          .setLngLat([lng, lat])
          .setPopup(popup)
          .addTo(this.map)
        this.allMarkers.push(mk) // <-- guardamos para conseguir limpar depois
      } else {
        const el = this._buildClusterMarker(items.length)
        const anchor = new mapboxgl.Marker({ element: el })
          .setLngLat([lng, lat])
          .addTo(this.map)
        this.allMarkers.push(anchor) // <-- idem

        el.addEventListener("click", (ev) => {
          ev.stopPropagation()
          if (this.spiderfied.has(key)) {
            this._collapseSpiderfied(key)
          } else {
            this._spiderfy(key, items)
          }
        })
        this.anchors.set(key, { marker: anchor, el })
      }
    })
  }

  // ----- Ajusta bounds -----
  _fitMapToMarkers() {
    const bounds = new mapboxgl.LngLatBounds()
    let hasAny = false
    this.groups.forEach((_, key) => {
      const [lat, lng] = key.split(",").map(Number)
      bounds.extend([lng, lat]); hasAny = true
    })
    if (hasAny) this.map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 0 })
    else { this.map.setCenter([-51.9253, -14.2350]); this.map.setZoom(3) }
  }

  // ----- Marker de preço que FILTRA -----
  _buildPriceMarker(priceText, title, url, serviceId) {
    const el = document.createElement("div")
    el.className = "price-marker"
    el.innerText = priceText || "•"
    el.title = title || ""
    el.setAttribute("role", "button")
    el.setAttribute("tabindex", "0")

    const goToOnlyThisService = () => {
      const base = window.location.pathname.split("?")[0].split("#")[0]
      const filterUrl = `${base}?service_id=${encodeURIComponent(serviceId)}#results`
      if (window.Turbo?.visit) window.Turbo.visit(filterUrl, { action: "advance" })
      else window.location.assign(filterUrl)
    }

    el.addEventListener("click", (e) => {
      e.stopPropagation()
      if ((e.metaKey || e.ctrlKey) && url) { window.open(url, "_blank"); return }
      goToOnlyThisService()
    })
    el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); goToOnlyThisService() }
    })

    return el
  }

  // ----- Spiderfy -----
  _spiderfy(key, items) {
    if (this.spiderfied.has(key)) return
    const [lat, lng] = key.split(",").map(Number)
    const center = new mapboxgl.LngLat(lng, lat)

    const children = []
    const lines = []
    const radiusPx = this._spiderRadius(items.length)

    items.forEach((m, i) => {
      const target = this._offsetLngLatByPixels(center, radiusPx, this._angleForIndex(i, items.length))
      const el = this._buildPriceMarker(m.price, m.name, m.url, m.service_id)
      const popup = new mapboxgl.Popup().setHTML(m.info_window_html)

      const child = new mapboxgl.Marker({ element: el })
        .setLngLat(target)
        .setPopup(popup)
        .addTo(this.map)
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

  // ----- Geometria / posicionamento -----
  _spiderRadius(n){ if(n<=4)return 60; if(n<=8)return 70; if(n<=12)return 100; return 120 }
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
        const newLngLat = this._offsetLngLatByPixels(center, data.radiusPx, this._angleForIndex(i, data.count))
        marker.setLngLat(newLngLat)
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
    const to = this.map.project(toLngLat)
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
    this.allLegs.push(leg) // segurança extra
    return leg
  }

  _groupMarkersByCoordinate() {
  this.groups.clear()
  let markers = this.markersValue
  if (typeof markers === "string") {
    try { markers = JSON.parse(markers) } catch (_) { markers = [] }
  }
  if (!Array.isArray(markers)) return
  markers.forEach(m => {
    const key = `${m.lat},${m.lng}`
    if (!this.groups.has(key)) this.groups.set(key, [])
    this.groups.get(key).push(m)
  })
  }
}
