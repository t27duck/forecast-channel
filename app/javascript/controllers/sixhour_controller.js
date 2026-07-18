import { Controller } from "@hotwired/stimulus"

// Toggles the 6-hour breakdown overlay on the Today/Tomorrow panels. Clicking
// the panel opens it (Escape or another click closes it) and swaps the green
// header title to the day's weekday, mirroring the Wii.
export default class extends Controller {
  static values = { day: String }

  connect() {
    // The green title is shared, fixed chrome (see locations/show).
    this.title = this.element.closest(".wii")?.querySelector(".wii-header__title")
    this.onKeydown = (event) => { if (event.key === "Escape") this.close() }
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
  }

  toggle() {
    this.element.classList.contains("is-open") ? this.close() : this.open()
  }

  open() {
    if (this.title && this.dayValue) {
      this.savedTitle = this.title.textContent // e.g. "Today"
      this.title.textContent = this.dayValue // e.g. "THURSDAY"
    }
    this.element.classList.add("is-open")
    window.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.element.classList.remove("is-open")
    if (this.title && this.savedTitle) this.title.textContent = this.savedTitle
    window.removeEventListener("keydown", this.onKeydown)
  }
}
