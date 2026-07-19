import { Controller } from "@hotwired/stimulus"

// Wii-style button press. Attached to the detail-view container, it watches
// for a press on any nav button and makes it dip toward the nearest screen
// edge and spring back — a one-shot CSS animation the bars own (top-bar
// buttons slide up, bottom-bar buttons slide down).
const BUTTON_SELECTOR = ".wii-arrow, .wii-chrome-link, .wii-mute"

export default class extends Controller {
  connect() {
    this.onPress = this.onPress.bind(this)
    this.element.addEventListener("pointerdown", this.onPress)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPress)
  }

  onPress(event) {
    const button = event.target.closest(BUTTON_SELECTOR)
    if (!button) return

    button.classList.remove("is-pressed")
    void button.offsetWidth // restart the animation when pressed again quickly
    button.classList.add("is-pressed")
    button.addEventListener(
      "animationend",
      () => button.classList.remove("is-pressed"),
      { once: true }
    )
  }
}
