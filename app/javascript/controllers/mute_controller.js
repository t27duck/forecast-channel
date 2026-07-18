import { Controller } from "@hotwired/stimulus"

// The mute/unmute button. Talks to the persistent jukebox controller via an
// outlet (they live on separate elements) and reflects the current state — the
// "is-muted" class drives which icon shows.
export default class extends Controller {
  static outlets = ["jukebox"]

  jukeboxOutletConnected(jukebox) {
    this.#render(jukebox.muted)
  }

  toggle() {
    if (!this.hasJukeboxOutlet) return
    this.#render(this.jukeboxOutlet.toggleMuted())
  }

  #render(muted) {
    this.element.classList.toggle("is-muted", muted)
    this.element.setAttribute("aria-pressed", muted ? "true" : "false")
  }
}
