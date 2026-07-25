import { Controller } from "@hotwired/stimulus"

// Mute/unmute. Talks to the persistent jukebox controller via an outlet (they
// live on separate elements) and reflects the current state.
//
// Two screens use it. The forecast bar's icon button *is* the controller
// element, and the "is-muted" class drives which icon shows. The settings page
// wraps a whole row, where the state reads as On/Off in the row's label target
// and the button beside it just says "Change", like every other settings row.
export default class extends Controller {
  static outlets = ["jukebox"]
  static targets = ["label"]

  jukeboxOutletConnected(jukebox) {
    this.#render(jukebox.muted)
  }

  toggle() {
    if (!this.hasJukeboxOutlet) return
    this.#render(this.jukeboxOutlet.toggleMuted())
  }

  #render(muted) {
    this.element.classList.toggle("is-muted", muted)
    if (this.hasLabelTarget) this.labelTarget.textContent = muted ? "Off" : "On"
    // Only meaningful on the icon button, which is itself the toggle; the
    // settings row's "Change" button reports no pressed state.
    if (this.element.tagName === "BUTTON") {
      this.element.setAttribute("aria-pressed", muted ? "true" : "false")
    }
  }
}
