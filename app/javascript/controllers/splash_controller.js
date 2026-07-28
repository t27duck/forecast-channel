import { Controller } from "@hotwired/stimulus"
import { WEATHER_READY } from "../lib/stream_actions"

const MIN_MS = 1600 // let the suns sweep at least once
const MAX_MS = 6000 // never hold anyone hostage to a slow weather service

// The loading screen at the root path. Holds for a beat — longer if the server
// said this location's weather needs refreshing, which the JSON request below
// performs — then hands over to the forecast. A click or key press skips
// straight there, and doubles as the gesture the jukebox needs to start playing.
export default class extends Controller {
  static values = { url: String, refresh: Boolean }

  connect() {
    this.handedOver = false
    this.skip = () => this.#handOver()
    document.addEventListener("pointerdown", this.skip)
    document.addEventListener("keydown", this.skip)

    const beat = this.#wait(MIN_MS)
    const work = this.refreshValue ? this.#refreshWeather() : Promise.resolve()
    const capitulate = this.#wait(MAX_MS)

    Promise.race([Promise.all([beat, work]), capitulate]).then(() => this.#handOver())
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.skip)
    document.removeEventListener("keydown", this.skip)
    window.removeEventListener(WEATHER_READY, this.onReady)
    this.timers?.forEach(clearTimeout)
  }

  // Same URL as this page: the JSON representation queues the refresh and
  // answers straight away, so what we're actually waiting for is the job
  // finishing — which arrives as a broadcast on the stream the page subscribed
  // to (see home/show). Listen before asking, so a quick job can't answer into
  // the gap. If the signal is missed anyway, MAX_MS is still the backstop it
  // always was.
  #refreshWeather() {
    return new Promise((resolve) => {
      this.onReady = () => resolve()
      window.addEventListener(WEATHER_READY, this.onReady, { once: true })

      fetch(window.location.pathname, { headers: { Accept: "application/json" } })
        .then((response) => response.json())
        // Nothing was queued after all — the weather went fresh between
        // rendering this page and asking. Don't wait for a signal nobody is
        // going to send.
        .then((body) => { if (!body.refreshing) resolve() })
        // A failure is still an answer: the forecast page renders whatever it
        // already has, which is what it would have shown regardless.
        .catch(() => resolve())
    })
  }

  #wait(ms) {
    return new Promise((resolve) => {
      this.timers ||= []
      this.timers.push(setTimeout(resolve, ms))
    })
  }

  // "replace" so the splash never enters history: coming back from the forecast
  // should reach whatever came before it, not play the loading screen again.
  #handOver() {
    if (this.handedOver) return

    this.handedOver = true
    window.Turbo.visit(this.urlValue, { action: "replace" })
  }
}
