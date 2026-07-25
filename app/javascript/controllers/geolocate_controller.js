import { Controller } from "@hotwired/stimulus"

// Backs the picker's "Use My Current Location" row: asks the browser for the
// visitor's coordinates and posts them so the server can pick the nearest
// location. The row is hidden in the markup and revealed here, so a browser
// without geolocation never shows a button that can't work.
export default class extends Controller {
  static targets = ["latitude", "longitude", "button", "label", "notice"]

  connect() {
    if (!navigator.geolocation) return

    this.buttonTarget.hidden = false
  }

  locate() {
    this.#busy(true)

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.latitudeTarget.value = position.coords.latitude
        this.longitudeTarget.value = position.coords.longitude
        this.element.requestSubmit()
      },
      // Denied, unavailable, or a page that isn't a secure origin: say so and
      // leave the list below as the way forward.
      () => {
        this.#busy(false)
        this.noticeTarget.textContent =
          "We couldn't get your location — choose it from the list below."
        this.noticeTarget.hidden = false
      },
      { timeout: 10000 }
    )
  }

  #busy(waiting) {
    this.buttonTarget.disabled = waiting
    this.labelTarget.textContent = waiting ? "Locating…" : "Use My Current Location"
    if (waiting) this.noticeTarget.hidden = true
  }
}
