import { Controller } from "@hotwired/stimulus"

// Wii-style background music. Picks a track from the current zone (the forecast
// screens vs the globe, via <body data-music-zone>) and the time of day (day
// 7am–7pm, night otherwise), and flips at those boundaries while the app stays
// open. Screens that name no zone are silent. Browsers block autoplay until a
// user gesture, so the first click/keypress starts it.
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
    // Through refresh, so a gesture on a silent screen doesn't start anything.
    this.onGesture = () => this.refresh()
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
    // A silent screen, or a zone whose track was never uploaded. Pause rather
    // than clear the source: the track keeps its position, so returning to a
    // musical screen picks up where it left off instead of starting over.
    if (!src) return audio.pause()

    if (src !== currentSrc) {
      currentSrc = src
      audio.src = src
    }
    this.#play()
  }

  get muted() {
    return audio.muted
  }

  // Whether anything is actually sounding. Nothing in the app reads this; it
  // lets a system test assert that a silent screen really is silent, which the
  // zone attribute alone can't show.
  get paused() {
    return audio.paused
  }

  // Flip mute, remember it, and (when unmuting) make sure playback is running.
  // Returns the new muted state so the button can update.
  //
  // Through refresh rather than play: the source left loaded by the last
  // musical screen is still there, paused, so unmuting on a silent screen —
  // the Sound row on the settings page — must not resume it.
  toggleMuted() {
    audio.muted = !audio.muted
    window.localStorage.setItem("jukeboxMuted", audio.muted ? "1" : "0")
    if (!audio.muted) this.refresh()
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

  // The track for this screen, or null where music doesn't belong. Zones are
  // opt-in (<body data-music-zone>, from content_for :music_zone), so anything
  // that doesn't ask for music — settings, the picker, the splash, the admin
  // screens — is silent by default rather than inheriting the forecast's track.
  #trackSrc() {
    const zone = document.body.dataset.musicZone
    const hour = new Date().getHours()
    const isDay = hour >= DAY_START_HOUR && hour < DAY_END_HOUR

    if (zone === "globe") return isDay ? this.globeDayValue : this.globeNightValue
    if (zone === "current") return isDay ? this.currentDayValue : this.currentNightValue
    return null
  }
}
