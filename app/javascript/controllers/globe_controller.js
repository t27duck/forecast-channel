import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"
import { WEATHER_ICONS } from "../lib/weather_icons"

// Standard basemap config properties we switch off (roads, transit, labels).
const HIDDEN_BASEMAP_FEATURES = [
  "showRoadsAndTransit",
  "showPedestrianRoads",
  "showPlaceLabels",
  "showPointOfInterestLabels",
  "showRoadLabels",
  "showTransitLabels",
  "showAdminBoundaries"
]

const SOURCE_ID = "locations"
const LAYER_ID = "location-markers"

// The "Next" button cycles the marker icons through these views; the green
// banner shows which one is on screen. `icon` names a GeoJSON feature property.
const WEATHER_MODES = [
  { icon: "icon", title: "Current Weather" },
  { icon: "icon_today", title: "Today's Weather" },
  { icon: "icon_tomorrow", title: "Tomorrow's Weather" }
]

// Degrees of tilt added/removed per pitch-button press; the "Restore" button
// returns to this default.
const PITCH_STEP = 15
const DEFAULT_PITCH = 0

const DEFAULT_ZOOM = 7
const DEFAULT_CENTER = [0, 20]

// The map remembers where it was left (per browser tab) so returning to it from
// another location's forecast resumes the same view.
const CAMERA_KEY = "globeCamera"

// Cursor state classes on the map container; the CSS picks the Wii hand.
const POINTING_CLASS = "is-pointing"
const GRABBING_CLASS = "is-grabbing"

// Leave the globe alone this long — or take the pointer off the page — and the
// chrome gets out of the way: the bars slide off their edges, the banner fades,
// and the cursor is hidden (all CSS, off this class). Any mouse movement brings
// it back.
const IDLE_CLASS = "is-idle"
const IDLE_AFTER = 2000

// Idling on the fully-zoomed-out globe also sets it turning, one revolution per
// SECONDS_PER_REVOLUTION. Any closer than SPIN_MAX_ZOOM and the drift reads as
// the map running away rather than as an idle animation.
const SPIN_MAX_ZOOM = 2
const SECONDS_PER_REVOLUTION = 180

// Icons display at ICON_SIZE px, rasterized at 2x (pixelRatio) for crispness.
const ICON_SIZE = 34
const ICON_PIXEL_RATIO = 2

// Renders the satellite globe and plots each location as a symbol in a single
// GeoJSON layer. Mapbox's built-in collision (icon/text "allow-overlap: false")
// declutters overlapping markers when zoomed out and reveals more on zoom-in;
// population is used as the priority so larger cities win a collision.
export default class extends Controller {
  static values = { token: String, markersUrl: String, center: Array, temperatureUnit: String }
  static targets = ["map", "zoomIn", "zoomOut", "banner", "pitchUp", "pitchDown"]

  connect() {
    if (!this.tokenValue) {
      console.warn("[globe] missing Mapbox token; skipping map render")
      return
    }

    this.modeIndex = 0
    if (this.hasBannerTarget) this.bannerTarget.textContent = WEATHER_MODES[0].title

    mapboxgl.accessToken = this.tokenValue

    const camera = this.#initialCamera()

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/standard-satellite",
      projection: "globe",
      center: camera.center,
      zoom: camera.zoom,
      pitch: camera.pitch,
      bearing: camera.bearing,
      attributionControl: false,
      minZoom: 2, // min 0 (fully zoomed out)
      maxZoom: 9 // max 22 (fully zoomed in)
    })

    this.element.__map = this.map // handle for system tests
    this.map.on("style.load", () => this.#setupScene())

    this.#watchIdle()
  }

  disconnect() {
    this.#unwatchIdle()
    this.popup?.remove()
    this.map?.remove()
  }

  // The overlaid zoom bar buttons — one Mapbox zoom unit per press.
  zoomIn() {
    this.map?.zoomIn()
  }

  zoomOut() {
    this.map?.zoomOut()
  }

  // Cycle the marker icons: Current -> Today -> Tomorrow -> Current.
  next() {
    this.modeIndex = (this.modeIndex + 1) % WEATHER_MODES.length
    this.#applyMode()
  }

  // The bottom-bar tilt controls.
  pitchUp() {
    this.#setPitch(this.map ? this.map.getPitch() + PITCH_STEP : DEFAULT_PITCH)
  }

  pitchDown() {
    this.#setPitch(this.map ? this.map.getPitch() - PITCH_STEP : DEFAULT_PITCH)
  }

  resetPitch() {
    this.#setPitch(DEFAULT_PITCH)
  }

  // Idle chrome ---------------------------------------------------------
  // Listening on the document (not the element) so a pointer resting on a bar
  // or wandering off the globe still counts; leaving the page skips the wait,
  // since a cursor that isn't here can't be about to do anything.
  #watchIdle() {
    this.onWake = () => this.#wake()
    this.onPointerLeave = () => this.#idle()

    document.addEventListener("mousemove", this.onWake)
    document.addEventListener("pointerdown", this.onWake)
    document.addEventListener("keydown", this.onWake)
    document.addEventListener("wheel", this.onWake, { passive: true })
    document.documentElement.addEventListener("mouseleave", this.onPointerLeave)

    this.#wake() // start the countdown as soon as the globe opens
  }

  #unwatchIdle() {
    clearTimeout(this.idleTimer)
    document.removeEventListener("mousemove", this.onWake)
    document.removeEventListener("pointerdown", this.onWake)
    document.removeEventListener("keydown", this.onWake)
    document.removeEventListener("wheel", this.onWake)
    document.documentElement.removeEventListener("mouseleave", this.onPointerLeave)
  }

  #wake() {
    clearTimeout(this.idleTimer)

    if (this.idle) {
      this.idle = false
      this.element.classList.remove(IDLE_CLASS)
      this.#stopSpin()
    }

    this.idleTimer = setTimeout(() => this.#idle(), IDLE_AFTER)
  }

  #idle() {
    if (this.idle) return

    clearTimeout(this.idleTimer)
    this.idle = true
    this.element.classList.add(IDLE_CLASS)
    this.#startSpin()
  }

  // Ambient rotation while idle: nudge the centre west and let Mapbox ease
  // there linearly over a second; the moveend handler queues the next nudge, so
  // the steps join into one continuous turn.
  #startSpin() {
    if (this.spinning || !this.map) return
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) return

    this.spinning = true
    this.#spinStep()
  }

  #spinStep() {
    if (!this.spinning || !this.map) return

    // Too close in to drift: stay armed rather than stopping, so idling through
    // a zoom back out (the next moveend) picks the turn up.
    if (this.map.getZoom() > SPIN_MAX_ZOOM + 1e-3) return

    const center = this.map.getCenter()
    center.lng -= 360 / SECONDS_PER_REVOLUTION
    this.map.easeTo({ center, duration: 1000, easing: (t) => t })
  }

  #stopSpin() {
    if (!this.spinning) return

    this.spinning = false
    this.map?.stop() // freeze where it is rather than coasting to the next step
  }

  #setPitch(target) {
    if (!this.map) return
    const clamped = Math.max(this.map.getMinPitch(), Math.min(target, this.map.getMaxPitch()))
    this.map.easeTo({ pitch: clamped, duration: 300 })
  }

  // Blank + disable the tilt buttons once their pitch limit is reached.
  #syncPitchButtons() {
    if (!this.map) return
    const pitch = this.map.getPitch()

    if (this.hasPitchUpTarget) {
      this.pitchUpTarget.disabled = pitch >= this.map.getMaxPitch() - 1e-3
    }
    if (this.hasPitchDownTarget) {
      this.pitchDownTarget.disabled = pitch <= this.map.getMinPitch() + 1e-3
    }
  }

  #applyMode() {
    const mode = WEATHER_MODES[this.modeIndex]
    if (this.hasBannerTarget) this.bannerTarget.textContent = mode.title
    this.popup?.remove() // a stale popup would show the previous view's weather
    if (this.map?.getLayer(LAYER_ID)) {
      this.map.setLayoutProperty(LAYER_ID, "icon-image", ["get", mode.icon])
    }
  }

  // Where the globe opens: centred on the location we came from (fresh), else
  // the view it was left at (resumed), else a default world view.
  #initialCamera() {
    if (this.hasCenterValue && this.centerValue.length === 2) {
      return { center: this.centerValue, zoom: DEFAULT_ZOOM, pitch: DEFAULT_PITCH, bearing: 0 }
    }

    const saved = this.#loadCamera()
    if (saved) return saved

    return { center: DEFAULT_CENTER, zoom: DEFAULT_ZOOM, pitch: DEFAULT_PITCH, bearing: 0 }
  }

  #saveCamera() {
    if (!this.map) return
    const center = this.map.getCenter()
    const state = {
      center: [center.lng, center.lat],
      zoom: this.map.getZoom(),
      pitch: this.map.getPitch(),
      bearing: this.map.getBearing()
    }
    try {
      window.sessionStorage.setItem(CAMERA_KEY, JSON.stringify(state))
    } catch {
      // sessionStorage unavailable (private mode / disabled) — non-fatal.
    }
  }

  #loadCamera() {
    try {
      const state = JSON.parse(window.sessionStorage.getItem(CAMERA_KEY))
      if (Array.isArray(state?.center) && state.center.length === 2) return state
    } catch {
      // Ignore missing or malformed state.
    }
    return null
  }

  async #setupScene() {
    const map = this.map

    map.setFog({
      "color": "#20519f",
      "high-color": "#1a3374",
      "space-color": "#030a1b",
      "star-intensity": 0.6,
      "horizon-blend": 0.03
    })

    // Strip roads, transit and labels from the Standard basemap for a clean
    // globe that foregrounds the weather markers.
    HIDDEN_BASEMAP_FEATURES.forEach((feature) => {
      map.setConfigProperty("basemap", feature, false)
    })

    await this.#registerIcons()
    this.#addMarkersLayer()
    this.#enableNavigation()
    this.#trackDragCursor()
    this.#applyMode() // sync icons/banner with the current view

    // Disable the +/- buttons at the zoom limits (and keep them in sync).
    map.on("zoom", () => this.#syncZoomButtons())
    this.#syncZoomButtons()

    // Same for the tilt buttons at the pitch limits.
    map.on("pitch", () => this.#syncPitchButtons())
    this.#syncPitchButtons()

    // Remember the view so returning to the map resumes where it was left.
    // Persist the initial camera too: arriving via ?location centres the globe
    // without firing a move, so without this an unpanned visit would never be
    // saved and a later plain /map visit would fall back to the world view.
    // The idle spin is the exception: it keeps the turn going instead, since
    // where an unattended globe happened to drift to isn't a view worth
    // resuming — the last place the viewer left it is.
    map.on("moveend", () => {
      if (this.spinning) this.#spinStep()
      else this.#saveCamera()
    })
    this.#saveCamera()

    this.element.dataset.mapReady = "true"
  }

  // Blank + disable the zoom-in/out button once its limit is reached.
  #syncZoomButtons() {
    if (!this.map) return
    const zoom = this.map.getZoom()

    if (this.hasZoomInTarget) {
      this.zoomInTarget.disabled = zoom >= this.map.getMaxZoom() - 1e-3
    }
    if (this.hasZoomOutTarget) {
      this.zoomOutTarget.disabled = zoom <= this.map.getMinZoom() + 1e-3
    }
  }

  // Pointing at a marker previews its weather; clicking opens its detail view.
  #enableNavigation() {
    const map = this.map

    map.on("click", LAYER_ID, (event) => {
      const id = event.features?.[0]?.properties?.id
      if (!id) return

      // Navigate through Turbo so the persistent music player survives (a full
      // reload would restart the track).
      const url = `/locations/${id}`
      if (window.Turbo) window.Turbo.visit(url)
      else window.location.assign(url)
    })

    this.popup = new mapboxgl.Popup({
      closeButton: false,
      closeOnClick: false,
      offset: 16,
      className: "globe-popup",
      maxWidth: "230px"
    })

    map.on("mouseenter", LAYER_ID, (event) => {
      this.element.classList.add(POINTING_CLASS)
      this.#showPopup(event.features?.[0])
    })
    map.on("mousemove", LAYER_ID, (event) => this.#showPopup(event.features?.[0]))
    map.on("mouseleave", LAYER_ID, () => {
      this.element.classList.remove(POINTING_CLASS)
      this.popup.remove()
    })
  }

  // Panning the globe closes the open hand into a fist (see the .map-view
  // cursor rules); the classes pick which Wii hand the canvas shows.
  #trackDragCursor() {
    this.map.on("dragstart", () => this.element.classList.add(GRABBING_CLASS))
    this.map.on("dragend", () => this.element.classList.remove(GRABBING_CLASS))
  }

  // Show the hovered marker's weather for the active view (current/today/
  // tomorrow), anchored to its coordinates.
  #showPopup(feature) {
    if (!feature) return
    this.popup
      .setLngLat(feature.geometry.coordinates)
      .setHTML(this.#popupHtml(feature.properties))
      .addTo(this.map)
  }

  #popupHtml(props) {
    const name = this.#escape(props.name)

    if (this.modeIndex === 0) {
      const temp = this.#formatTemp(props.temp)
      const hi = this.#formatTemp(props.today_high)
      const lo = this.#formatTemp(props.today_low)
      const hilo = hi && lo ? `<div class="gp__hilo">H ${hi} · L ${lo}</div>` : ""
      return `<div class="gp"><div class="gp__name">${name}</div>` +
        (temp ? `<div class="gp__temp">${temp}</div>` : `<div class="gp__muted">No reading yet</div>`) +
        (props.label ? `<div class="gp__cond">${this.#escape(props.label)}</div>` : "") +
        hilo + "</div>"
    }

    const prefix = this.modeIndex === 1 ? "today" : "tomorrow"
    const hi = this.#formatTemp(props[`${prefix}_high`])
    const lo = this.#formatTemp(props[`${prefix}_low`])
    const label = props[`${prefix}_label`]
    const hilo = hi && lo ? `<div class="gp__temp">${hi} <span class="gp__slash">/</span> ${lo}</div>`
      : `<div class="gp__muted">No forecast yet</div>`
    return `<div class="gp"><div class="gp__name">${name}</div>` +
      (label ? `<div class="gp__cond">${this.#escape(label)}</div>` : "") +
      hilo + "</div>"
  }

  // Round a Celsius value into the viewer's unit, e.g. "19°". Null when absent.
  #formatTemp(celsius) {
    if (celsius === null || celsius === undefined || celsius === "") return null
    const c = Number(celsius)
    if (Number.isNaN(c)) return null
    const value = this.temperatureUnitValue === "fahrenheit" ? c * 9 / 5 + 32 : c
    return `${Math.round(value)}°`
  }

  #escape(text) {
    return String(text ?? "").replace(/[&<>]/g, (ch) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;" }[ch]
    ))
  }

  // Rasterize each weather SVG and register it as a named map image.
  #registerIcons() {
    return Promise.all(
      Object.entries(WEATHER_ICONS).map(([name, svg]) => this.#registerIcon(name, svg))
    )
  }

  #registerIcon(name, svg) {
    if (this.map.hasImage(name)) return Promise.resolve()

    return new Promise((resolve) => {
      const size = ICON_SIZE * ICON_PIXEL_RATIO
      const image = new Image(size, size)
      image.onload = () => {
        if (!this.map.hasImage(name)) {
          this.map.addImage(name, image, { pixelRatio: ICON_PIXEL_RATIO })
        }
        resolve()
      }
      image.onerror = () => resolve()
      image.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg)
    })
  }

  #addMarkersLayer() {
    const map = this.map

    if (!map.getSource(SOURCE_ID)) {
      map.addSource(SOURCE_ID, { type: "geojson", data: this.markersUrlValue })
    }

    if (map.getLayer(LAYER_ID)) return

    map.addLayer({
      id: LAYER_ID,
      type: "symbol",
      source: SOURCE_ID,
      layout: {
        "icon-image": ["get", "icon"],
        "icon-allow-overlap": false,
        // Larger population -> smaller sort key -> placed first -> wins collision.
        "symbol-sort-key": ["-", ["to-number", ["get", "population"], 0]],
        "text-field": ["get", "name"],
        "text-font": ["DIN Pro Medium", "Arial Unicode MS Regular"],
        "text-size": 12,
        "text-anchor": "left",
        "text-offset": [1.4, 0],
        "text-allow-overlap": false,
        "text-optional": true // keep the icon even if its label can't be placed
      },
      paint: {
        "text-color": "#ffffff",
        "text-halo-color": "#030a1b",
        "text-halo-width": 1.4,
        "text-halo-blur": 0.5
      }
    })
  }
}
