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

// Icons display at ICON_SIZE px, rasterized at 2x (pixelRatio) for crispness.
const ICON_SIZE = 34
const ICON_PIXEL_RATIO = 2

// Renders the satellite globe and plots each location as a symbol in a single
// GeoJSON layer. Mapbox's built-in collision (icon/text "allow-overlap: false")
// declutters overlapping markers when zoomed out and reveals more on zoom-in;
// population is used as the priority so larger cities win a collision.
export default class extends Controller {
  static values = { token: String, markersUrl: String }
  static targets = ["map", "zoomIn", "zoomOut", "banner", "pitchUp", "pitchDown"]

  connect() {
    if (!this.tokenValue) {
      console.warn("[globe] missing Mapbox token; skipping map render")
      return
    }

    this.modeIndex = 0
    if (this.hasBannerTarget) this.bannerTarget.textContent = WEATHER_MODES[0].title

    mapboxgl.accessToken = this.tokenValue

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: "mapbox://styles/mapbox/standard-satellite",
      projection: "globe",
      center: [0, 20],
      zoom: 7,
      attributionControl: false,
      minZoom: 2, // min 0 (fully zoomed out)
      maxZoom: 9 // max 22 (fully zoomed in)
    })

    this.element.__map = this.map // handle for system tests
    this.map.on("style.load", () => this.#setupScene())
  }

  disconnect() {
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
    if (this.map?.getLayer(LAYER_ID)) {
      this.map.setLayoutProperty(LAYER_ID, "icon-image", ["get", mode.icon])
    }
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
    this.#applyMode() // sync icons/banner with the current view

    // Disable the +/- buttons at the zoom limits (and keep them in sync).
    map.on("zoom", () => this.#syncZoomButtons())
    this.#syncZoomButtons()

    // Same for the tilt buttons at the pitch limits.
    map.on("pitch", () => this.#syncPitchButtons())
    this.#syncPitchButtons()

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

  // Clicking a marker opens that location's detail view.
  #enableNavigation() {
    const map = this.map

    map.on("click", LAYER_ID, (event) => {
      const id = event.features?.[0]?.properties?.id
      if (id) window.location.assign(`/locations/${id}`)
    })

    map.on("mouseenter", LAYER_ID, () => { map.getCanvas().style.cursor = "pointer" })
    map.on("mouseleave", LAYER_ID, () => { map.getCanvas().style.cursor = "" })
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
