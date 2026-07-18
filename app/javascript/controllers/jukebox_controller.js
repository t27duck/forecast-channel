import { Controller } from "@hotwired/stimulus"

// Wii-style background music. Lives on a data-turbo-permanent element so it
// keeps playing across Turbo navigations. Picks a track from the current zone
// (the forecast screens vs the globe, via <body data-music-zone>) and the time
// of day (day 7am–7pm, night otherwise), and flips at those boundaries while
// the app stays open. Browsers block autoplay until a user gesture, so the
// first click/keypress starts it.
const DAY_START_HOUR = 7
const DAY_END_HOUR = 19

export default class extends Controller {
  static values = {
    currentDay: String, currentNight: String, globeDay: String, globeNight: String
  }

  connect() {
    this.audio = new Audio()
    this.audio.loop = true
    this.audio.preload = "none" // don't fetch the (large) track until it plays
    this.audio.muted = window.localStorage.getItem("jukeboxMuted") === "1"
    this.currentSrc = null

    this.refresh()

    this.onTurboLoad = () => this.refresh()
    document.addEventListener("turbo:load", this.onTurboLoad)

    // Re-check the zone/time roughly every minute (covers the 7am/7pm flip).
    this.timer = setInterval(() => this.refresh(), 60_000)

    // Autoplay is blocked until the user interacts; start on the first gesture.
    this.onGesture = () => this.#play()
    document.addEventListener("pointerdown", this.onGesture)
    document.addEventListener("keydown", this.onGesture)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.onTurboLoad)
    this.#stopWaitingForGesture()
    clearInterval(this.timer)
    this.audio?.pause()
  }

  refresh() {
    const src = this.#trackSrc()
    if (src && src !== this.currentSrc) {
      this.currentSrc = src
      this.audio.src = src
    }
    this.#play()
  }

  get muted() {
    return this.audio.muted
  }

  // Flip mute, remember it, and (when unmuting) make sure playback is running.
  // Returns the new muted state so the button can update.
  toggleMuted() {
    this.audio.muted = !this.audio.muted
    window.localStorage.setItem("jukeboxMuted", this.audio.muted ? "1" : "0")
    if (!this.audio.muted) this.#play()
    return this.audio.muted
  }

  #play() {
    const started = this.audio.play()
    if (started) started.then(() => this.#stopWaitingForGesture()).catch(() => {})
  }

  #stopWaitingForGesture() {
    document.removeEventListener("pointerdown", this.onGesture)
    document.removeEventListener("keydown", this.onGesture)
  }

  #trackSrc() {
    const onGlobe = document.body.dataset.musicZone === "globe"
    const hour = new Date().getHours()
    const isDay = hour >= DAY_START_HOUR && hour < DAY_END_HOUR

    if (onGlobe) return isDay ? this.globeDayValue : this.globeNightValue
    return isDay ? this.currentDayValue : this.currentNightValue
  }
}
