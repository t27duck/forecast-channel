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

    // A weather refresh morphs this panel's contents in, and the server's
    // markup has no is-open class — so an overlay open at that moment would
    // shut itself. The title survives on its own: it lives in the permanent
    // header, which the morph doesn't touch.
    this.onMorph = () => {
      if (this.opened) this.element.classList.add("is-open")
    }
    document.addEventListener("turbo:morph", this.onMorph)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:morph", this.onMorph)
  }

  toggle() {
    this.opened ? this.close() : this.open()
  }

  open() {
    if (this.title && this.dayValue) {
      this.savedTitle = this.title.textContent // e.g. "Today"
      this.title.textContent = this.dayValue // e.g. "THURSDAY"
    }
    // Tracked here rather than read back off the class, so it still says what
    // the reader chose after a morph has stripped the class off.
    this.opened = true
    this.element.classList.add("is-open")
    window.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.opened = false
    this.element.classList.remove("is-open")
    if (this.title && this.savedTitle) this.title.textContent = this.savedTitle
    window.removeEventListener("keydown", this.onKeydown)
  }
}
