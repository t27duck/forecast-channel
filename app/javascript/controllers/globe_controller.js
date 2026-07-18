import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"
import { weatherIcon } from "../lib/weather_icons"

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

// Renders the satellite globe and plots a weather marker for each location.
// Expects a Mapbox token and the locations payload via Stimulus values.
export default class extends Controller {
  static values = { token: String, locations: Array }

  connect() {
    if (!this.tokenValue) {
      console.warn("[globe] missing Mapbox token; skipping map render")
      return
    }

    mapboxgl.accessToken = this.tokenValue

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/standard-satellite",
      projection: "globe",
      center: [0, 20],
      zoom: 1.4,
      attributionControl: false
    })

    this.map.on("style.load", () => {
      this.map.setFog({
        "color": "#20519f",
        "high-color": "#1a3374",
        "space-color": "#030a1b",
        "star-intensity": 0.6,
        "horizon-blend": 0.03
      })

      // Strip roads, transit and labels from the Standard basemap for a clean
      // globe that foregrounds the weather markers.
      HIDDEN_BASEMAP_FEATURES.forEach((feature) => {
        this.map.setConfigProperty("basemap", feature, false)
      })
    })

    this.markers = this.locationsValue.map((location) => this.#addMarker(location))
  }

  disconnect() {
    this.markers?.forEach((marker) => marker.remove())
    this.map?.remove()
  }

  #addMarker(location) {
    const element = document.createElement("div")
    element.className = "weather-marker"

    const icon = document.createElement("div")
    icon.className = "weather-marker__icon"
    icon.innerHTML = weatherIcon(location.condition_code)

    const label = document.createElement("div")
    label.className = "weather-marker__label"
    label.textContent = location.name // set as text so names can't inject markup

    element.append(icon, label)

    return new mapboxgl.Marker({ element, anchor: "left" })
      .setLngLat([location.longitude, location.latitude])
      .addTo(this.map)
  }
}
