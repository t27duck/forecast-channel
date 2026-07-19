import { Controller } from "@hotwired/stimulus"

// Wii-style background music. Picks a track from the current zone (the forecast
// screens vs the globe, via <body data-music-zone>) and the time of day (day
// 7am–7pm, night otherwise), and flips at those boundaries while the app stays
// open. Browsers block autoplay until a user gesture, so the first click/keypress
// starts it.
//
// The Audio and its current source live at MODULE scope, not on the controller
// instance: the player element is data-turbo-permanent, but Turbo moves it
// between pages on each navigation, which makes Stimulus disconnect and reconnect
// the controller. Keeping the audio here means a reconnect resumes the same
// playing track instead of building a fresh Audio and restarting it.
const DAY_START_HOUR = 7
const DAY_END_HOUR = 19

let audio = null
let currentSrc = null
let generation = 0 // bumps only when a new Audio is built (once); a test hook

export default class extends Controller {
  static values = {
    currentDay: String, currentNight: String, globeDay: String, globeNight: String
  }

  connect() {
    if (!audio) {
      audio = new Audio()
      audio.loop = true
      audio.preload = "none" // don't fetch the (large) track until it plays
      generation += 1
    }
    audio.muted = window.localStorage.getItem("jukeboxMuted") === "1"
    this.element.dataset.generation = generation

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
    // Intentionally does NOT pause: the audio must keep playing while Turbo
    // re-inserts this element on the next page.
  }

  refresh() {
    const src = this.#trackSrc()
    if (src && src !== currentSrc) {
      currentSrc = src
      audio.src = src
    }
    this.#play()
  }

  get muted() {
    return audio.muted
  }

  // Flip mute, remember it, and (when unmuting) make sure playback is running.
  // Returns the new muted state so the button can update.
  toggleMuted() {
    audio.muted = !audio.muted
    window.localStorage.setItem("jukeboxMuted", audio.muted ? "1" : "0")
    if (!audio.muted) this.#play()
    return audio.muted
  }

  #play() {
    const started = audio.play()
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
