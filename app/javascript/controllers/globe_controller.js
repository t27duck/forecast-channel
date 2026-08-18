import { Controller } from "@hotwired/stimulus"
import mapboxgl from "mapbox-gl"
import { WEATHER_ICONS } from "../lib/weather_icons"

// Name only, not an import: stream_actions.js is registered by the main bundle,
// and mapbox-gl is why this controller ships in its own. Neither bundle can
// reach into the other, so the window event is the seam between them.
const WEATHER_REFRESHED = "forecast:weather-refreshed"

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

// Space around the globe: the atmosphere ring, the colour beyond it, and the
// stars. Named here rather than written into #dressBasemap because the server
// can tint it for an occasion (SeasonalTheme — orange on black at Halloween),
// which arrives as the `fog` value; this is what it falls back to.
const DEFAULT_FOG = {
  "color": "#20519f",
  "high-color": "#1a3374",
  "space-color": "#030a1b",
  "star-intensity": 0.6,
  "horizon-blend": 0.03
}

// The Konami code unrolls the globe into a flat map and back (see maps/show,
// which wires the `sequence` controller to #toggleProjection). Remembered
// across visits in localStorage the way the jukebox remembers being muted: once
// found, found — and the code toggles it again to put the world back.
const PROJECTION_KEY = "globeProjection"
const ROUND_PROJECTION = "globe"
const FLAT_PROJECTION = "mercator"

// How long the banner holds an announcement before going back to naming the
// marker view it normally names.
const ANNOUNCE_MS = 2500

// The satellite basemap, and the stand-in used when no Mapbox token is
// configured. The fallback is a valid empty style with nothing in it, so the
// globe still builds and everything of ours on top of it — markers, controls,
// the idle chrome — works and can be tested; what's missing is Mapbox's own
// output, the imagery. Nothing is fetched from Mapbox: `glyphs` has to be
// declared or the style validator strips `text-field` (and with it the whole
// marker layer), but it points at a same-origin path that doesn't exist, so
// labels just don't draw.
const SATELLITE_STYLE = "mapbox://styles/mapbox/standard-satellite"
const OFFLINE_STYLE = {
  version: 8,
  glyphs: "/fonts/{fontstack}/{range}.pbf",
  sources: {},
  layers: []
}

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
// Where the globe opens when it has nothing better to go on. New York, at the
// coordinates db/seeds.rb gives it — somewhere with markers on it, rather than
// the empty Atlantic the old [0, 20] put you over at this zoom.
const DEFAULT_CENTER = [-74.00597, 40.71427]

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

// "Tour" flies the globe from city to city — the attract mode for the zoom the
// globe actually opens at, where the idle drift above deliberately doesn't run.
// Each stop is a flight of TOUR_FLY_MS, then its weather card for TOUR_DWELL_MS.
const TOURING_CLASS = "is-touring"
const TOUR_ZOOM = 5
const TOUR_PITCH = 40
const TOUR_FLY_MS = 4000
const TOUR_DWELL_MS = 3500

// Icons display at ICON_SIZE px, rasterized at 2x (pixelRatio) for crispness.
const ICON_SIZE = 34
const ICON_PIXEL_RATIO = 2

// A refresh sweep runs in chunks of WeatherRefresher::BATCH_SIZE, so it
// announces itself several times in quick succession. Wait this long after the
// last one before re-reading the feed, and the whole sweep costs one fetch.
const REFETCH_DEBOUNCE = 3000

// Renders the satellite globe and plots each location as a symbol in a single
// GeoJSON layer. Mapbox's built-in collision (icon/text "allow-overlap: false")
// declutters overlapping markers when zoomed out and reveals more on zoom-in;
// population is used as the priority so larger cities win a collision.
export default class extends Controller {
  static values = {
    token: String, markersUrl: String, center: Array, temperatureUnit: String, tour: Array,
    fog: Object
  }
  static targets = ["map", "zoomIn", "zoomOut", "banner", "pitchUp", "pitchDown", "tourButton"]

  connect() {
    // No token (CI, or a checkout with no MAPBOX_TOKEN set): build the globe on
    // the offline style instead of not building it at all. `testMode` silences
    // Mapbox's missing-token complaints.
    this.offline = !this.tokenValue
    if (this.offline) console.warn("[globe] no Mapbox token; rendering the offline style")

    this.modeIndex = 0
    if (this.hasBannerTarget) this.bannerTarget.textContent = WEATHER_MODES[0].title

    mapboxgl.accessToken = this.tokenValue

    const camera = this.#initialCamera()

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: this.offline ? OFFLINE_STYLE : SATELLITE_STYLE,
      testMode: this.offline,
      projection: this.#storedProjection(),
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
    this.#watchWeather()
    this.#watchTour()
  }

  disconnect() {
    clearTimeout(this.announceTimer)
    this.#unwatchIdle()
    this.#unwatchWeather()
    this.#unwatchTour()
    this.popup?.remove()
    this.map?.remove()
  }

  // The overlaid zoom bar buttons — one Mapbox zoom unit per press. Taking the
  // camera anywhere by hand ends a running tour, which would only fly out of it
  // again at the next stop.
  zoomIn() {
    this.#stopTour()
    this.map?.zoomIn()
  }

  zoomOut() {
    this.#stopTour()
    this.map?.zoomOut()
  }

  // Cycle the marker icons: Current -> Today -> Tomorrow -> Current. Unlike the
  // camera controls this leaves a tour running — it changes what the markers
  // show, not where the globe is looking, and the tour's card follows it.
  next() {
    this.modeIndex = (this.modeIndex + 1) % WEATHER_MODES.length
    this.#applyMode()
  }

  // The bottom-bar tilt controls.
  pitchUp() {
    this.#stopTour()
    this.#setPitch(this.map ? this.map.getPitch() + PITCH_STEP : DEFAULT_PITCH)
  }

  pitchDown() {
    this.#stopTour()
    this.#setPitch(this.map ? this.map.getPitch() - PITCH_STEP : DEFAULT_PITCH)
  }

  resetPitch() {
    this.#stopTour()
    this.#setPitch(DEFAULT_PITCH)
  }

  // The bottom bar's play/stop button.
  toggleTour() {
    if (this.touring) this.#stopTour()
    else this.#startTour()
  }

  // No button anywhere reaches this — it is the Konami code's, wired in
  // maps/show. Flattening a globe is the one joke an app like this owes its
  // visitors, and the flat map is genuinely usable, so it is left switched on
  // until the code is typed again.
  //
  // Fog and the star field only draw under the globe projection, so flattening
  // simply hides them; nothing has to be torn down. The saved camera doesn't
  // care either way, and the idle drift eases longitude, so that still works.
  toggleProjection() {
    if (!this.map) return

    const flat = this.map.getProjection().name !== FLAT_PROJECTION
    const projection = flat ? FLAT_PROJECTION : ROUND_PROJECTION

    this.map.setProjection(projection)
    this.#storeProjection(projection)
    this.#announce(flat ? "Flat Earth Mode" : "Round Earth Restored")
  }

  // Idle chrome ---------------------------------------------------------
  // Listening on the document (not the element) so a pointer resting on a bar
  // or wandering off the globe still counts; leaving the page skips the wait,
  // since a cursor that isn't here can't be about to do anything.
  #watchIdle() {
    this.onWake = () => this.#wake()
    this.onPointerLeave = () => this.#idle()

    // pointermove, not mousemove: a finger produces no mouse movement, so on a
    // phone the only thing keeping the bars up would be pointerdown — which
    // fires once at the start of a pan and then not again, so two seconds into
    // a drag the chrome would slide away and #startSpin would set the globe
    // easing west against the finger. Pointer events cover mouse, pen and touch
    // in one listener.
    document.addEventListener("pointermove", this.onWake, { passive: true })
    document.addEventListener("pointerdown", this.onWake)
    document.addEventListener("keydown", this.onWake)
    document.addEventListener("wheel", this.onWake, { passive: true })
    document.documentElement.addEventListener("mouseleave", this.onPointerLeave)

    this.#wake() // start the countdown as soon as the globe opens
  }

  #unwatchIdle() {
    clearTimeout(this.idleTimer)
    document.removeEventListener("pointermove", this.onWake)
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
    // A tour is already flying the camera, and the two share the moveend chain
    // below: arming the spin would capture it and strand the tour at its stop.
    if (this.touring) return
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

  // Tour -----------------------------------------------------------------
  // The stops are the biggest cities in longitude order (see MapsController),
  // so the tour walks eastward around the world. Unlike the idle spin this one
  // is asked for, so it survives the mouse moving — that only brings the chrome
  // back so the button is reachable. Escape, a gesture on the globe or any of
  // the camera buttons hand control back.
  #watchTour() {
    this.onTourKey = (event) => {
      if (event.key === "Escape") this.#stopTour()
    }
    document.addEventListener("keydown", this.onTourKey)
  }

  #unwatchTour() {
    clearTimeout(this.tourTimer)
    document.removeEventListener("keydown", this.onTourKey)
  }

  #startTour() {
    if (!this.map || this.tourValue.length < 2) return

    this.touring = true
    this.#syncTourButton()
    this.#stopSpin() // it may have been left drifting
    this.tourWeather = this.#loadTourWeather() // in flight before the first stop

    // Join the route at the first stop east of the current view, so the opening
    // hop is as short as the ones that follow it. `wrap`, because a globe left
    // spinning reports a longitude that has run well past 180.
    const here = this.map.getCenter().wrap().lng
    const next = this.tourValue.findIndex((stop) => stop.lng > here)
    this.tourIndex = next === -1 ? 0 : next

    this.#flyToStop()
  }

  #stopTour() {
    if (!this.touring) return

    clearTimeout(this.tourTimer)
    this.touring = false
    this.#syncTourButton()
    this.popup?.remove()
    this.map?.stop() // land where it is rather than finishing the flight
    this.#saveCamera() // nothing was saved while touring; keep where it ended
  }

  #flyToStop() {
    const stop = this.tourValue[this.tourIndex]
    if (!stop || !this.map) return

    this.popup?.remove() // the card belongs to the city we're leaving
    // Deliberately not `essential: true`: Mapbox skips a non-essential camera
    // animation for a visitor who asked for reduced motion and jumps there
    // instead, which is the right tour for them — every stop and every card,
    // without the swoop.
    this.map.flyTo({
      center: [ stop.lng, stop.lat ],
      zoom: TOUR_ZOOM,
      pitch: TOUR_PITCH,
      bearing: 0,
      duration: TOUR_FLY_MS
    })
  }

  // Arrived (via the moveend chain, as the spin does): show the city's weather,
  // hold it, then move on.
  #holdThenAdvance() {
    this.#showTourPopup()

    clearTimeout(this.tourTimer)
    this.tourTimer = setTimeout(() => {
      this.tourIndex = (this.tourIndex + 1) % this.tourValue.length
      this.#flyToStop()
    }, TOUR_DWELL_MS)
  }

  // The cards come from the marker feed rather than from the itinerary, so they
  // show what the last refresh wrote rather than what was true when the page was
  // rendered. Fetched here rather than read back out of the map with
  // querySourceFeatures: what Mapbox has parsed into source tiles depends on the
  // style having loaded the glyphs for the layer's labels, which the token-less
  // offline style never does — that lookup finds nothing on a globe with no
  // Mapbox account behind it.
  async #loadTourWeather(url = this.markersUrlValue) {
    try {
      const { features } = await (await fetch(url)).json()
      return new Map(features.map((feature) => [ feature.properties.slug, feature ]))
    } catch {
      return null // no cards, but the tour itself still flies
    }
  }

  // A stop with no feature — one deleted since, or a feed that didn't load —
  // simply gets no card: #showPopup ignores a missing feature.
  async #showTourPopup() {
    const index = this.tourIndex
    const stop = this.tourValue[index]
    if (!this.touring || !stop) return

    const features = await this.tourWeather
    if (!this.touring || this.tourIndex !== index) return // moved on while waiting

    this.#showPopup(features?.get(stop.slug))
  }

  #syncTourButton() {
    if (!this.hasTourButtonTarget) return

    this.tourButtonTarget.classList.toggle(TOURING_CLASS, Boolean(this.touring))
    this.tourButtonTarget.setAttribute("aria-pressed", String(Boolean(this.touring)))
  }

  // Live weather ---------------------------------------------------------
  // The page subscribes to the batch-refresh stream (see maps/show); the custom
  // Turbo Stream action turns each broadcast into this window event.
  #watchWeather() {
    this.onWeatherRefreshed = (event) => this.#scheduleRefetch(event.detail?.version)
    window.addEventListener(WEATHER_REFRESHED, this.onWeatherRefreshed)
  }

  #unwatchWeather() {
    clearTimeout(this.refetchTimer)
    window.removeEventListener(WEATHER_REFRESHED, this.onWeatherRefreshed)
  }

  #scheduleRefetch(version) {
    clearTimeout(this.refetchTimer)
    this.refetchTimer = setTimeout(() => this.#refetchMarkers(version), REFETCH_DEBOUNCE)
  }

  // Swap in the rebuilt feed. Only the source's data changes: the layer reads
  // its icon from a feature property (see #applyMode), so whichever of
  // Current/Today/Tomorrow is on screen survives, as does the camera — which
  // matters most when this lands on a globe that's been left spinning.
  #refetchMarkers(version) {
    const source = this.map?.getSource(SOURCE_ID)
    if (!source) return

    this.popup?.remove() // it holds a snapshot, so it would keep the old numbers
    // The markers response is cached and revalidated; the version defeats a
    // conditional GET handing back the bytes this refresh just invalidated.
    const url = version ? `${this.markersUrlValue}?v=${version}` : this.markersUrlValue
    source.setData(url)

    // A tour is parked on a city with its card open; put it back, with the new
    // numbers, once it has read the rebuilt feed too.
    if (this.touring) {
      this.tourWeather = this.#loadTourWeather(url)
      this.#showTourPopup()
    }
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

  // The banner's resting text: whichever of Current/Today/Tomorrow is showing.
  #showModeTitle() {
    if (this.hasBannerTarget) this.bannerTarget.textContent = WEATHER_MODES[this.modeIndex].title
  }

  // Borrow the banner to say something for a moment, then give it back to
  // whichever marker view is on screen. Its own method because #applyMode owns
  // that text, and this is the second thing that wants to speak through it.
  #announce(text) {
    if (!this.hasBannerTarget) return

    clearTimeout(this.announceTimer)
    this.bannerTarget.textContent = text
    this.announceTimer = setTimeout(() => this.#showModeTitle(), ANNOUNCE_MS)
  }

  // Read before the map is built rather than set afterwards, so an unlocked
  // visitor's globe opens flat instead of visibly unrolling on every arrival.
  #storedProjection() {
    try {
      return window.localStorage.getItem(PROJECTION_KEY) === FLAT_PROJECTION
        ? FLAT_PROJECTION
        : ROUND_PROJECTION
    } catch {
      return ROUND_PROJECTION
    }
  }

  #storeProjection(projection) {
    try {
      window.localStorage.setItem(PROJECTION_KEY, projection)
    } catch {
      // Private browsing with storage denied: the flat map still works, it
      // just won't survive the reload. Not worth failing the toggle over.
    }
  }

  #applyMode() {
    const mode = WEATHER_MODES[this.modeIndex]
    clearTimeout(this.announceTimer) // don't let a pending restore land later
    this.#showModeTitle()
    this.popup?.remove() // a stale popup would show the previous view's weather
    if (this.map?.getLayer(LAYER_ID)) {
      this.map.setLayoutProperty(LAYER_ID, "icon-image", ["get", mode.icon])
    }
  }

  // Where the globe opens: centred on the location we came from (fresh), else
  // the view it was left at (resumed), else New York.
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

    // Atmosphere and basemap config belong to the satellite style; the offline
    // fallback has neither to configure.
    if (!this.offline) this.#dressBasemap()

    await this.#registerIcons()
    this.#addMarkersLayer()
    this.#enableNavigation()
    this.#trackDragCursor()
    this.#watchTourGestures()
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
    // The idle spin and the tour are the exceptions: each chains its own next
    // move from here instead, since where an unattended globe happened to get
    // to isn't a view worth resuming — the last place the viewer left it is.
    map.on("moveend", () => {
      if (this.spinning) this.#spinStep()
      else if (this.touring) this.#holdThenAdvance()
      else this.#saveCamera()
    })
    this.#saveCamera()

    this.element.dataset.mapReady = "true"
  }

  // The space around the globe (see DEFAULT_FOG), and a basemap stripped of
  // roads, transit and labels so the weather markers are what you look at.
  #dressBasemap() {
    this.map.setFog(this.hasFogValue ? this.fogValue : DEFAULT_FOG)

    HIDDEN_BASEMAP_FEATURES.forEach((feature) => {
      this.map.setConfigProperty("basemap", feature, false)
    })
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
      const slug = event.features?.[0]?.properties?.slug
      if (!slug) return

      // Navigate through Turbo so the persistent music player survives (a full
      // reload would restart the track).
      const url = `/locations/${slug}`
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

  // Taking hold of the globe — dragging, scrolling to zoom, right-dragging to
  // rotate — ends a tour and hands the camera back. Mapbox tags a camera event
  // it started with the DOM event behind it, and the tour's own flyTo carries
  // none, so this can't stop the tour it's watching.
  #watchTourGestures() {
    [ "dragstart", "zoomstart", "rotatestart", "pitchstart" ].forEach((type) => {
      this.map.on(type, (event) => {
        if (event.originalEvent) this.#stopTour()
      })
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
