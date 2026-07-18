import { Controller } from "@hotwired/stimulus"

// On first visit (no chosen location), asks the browser for the user's
// coordinates and posts them so the server can pick the nearest location. If
// permission is denied or geolocation is unavailable, the default location
// stays — nothing else happens.
export default class extends Controller {
  static targets = ["latitude", "longitude"]

  connect() {
    if (!navigator.geolocation) return

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.latitudeTarget.value = position.coords.latitude
        this.longitudeTarget.value = position.coords.longitude
        this.element.requestSubmit()
      },
      () => {} // denied or unavailable: keep the default location
    )
  }
}
