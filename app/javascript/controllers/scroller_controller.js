import { Controller } from "@hotwired/stimulus"

// Scrolls the list target by roughly a page when the ▲/▼ bar buttons are used,
// mirroring the Wii location picker.
export default class extends Controller {
  static targets = ["list"]

  up() { this.#scroll(-1) }
  down() { this.#scroll(1) }

  #scroll(direction) {
    this.listTarget.scrollBy({ top: direction * this.listTarget.clientHeight * 0.8, behavior: "smooth" })
  }
}
