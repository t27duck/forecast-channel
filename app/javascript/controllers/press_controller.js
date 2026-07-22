import { Controller } from "@hotwired/stimulus"

// Wii-style button press. Attached to a bar/container, it watches for a button
// activation and makes that button dip toward the nearest screen edge and
// spring back — a one-shot CSS animation the bars own (top-bar buttons slide
// up, bottom-bar buttons slide down).
//
// The dip runs on `click`, not `pointerdown`, on purpose: the animation
// translates the button by up to 10px, so starting it on press would move the
// button out from under the cursor before release, and a mouseup over the
// vacated slot would never dispatch a click to the button (breaking its
// action). Firing on click keeps the button still through the press — the
// click always lands — and, as a bonus, the dip now also plays for keyboard
// (Enter/Space) activation.
const BUTTON_SELECTOR = ".wii-arrow, .wii-chrome-link, .wii-mute"

export default class extends Controller {
  connect() {
    this.onPress = this.onPress.bind(this)
    this.element.addEventListener("click", this.onPress)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onPress)
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
