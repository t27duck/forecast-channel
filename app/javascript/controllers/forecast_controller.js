import { Controller } from "@hotwired/stimulus"

// Drives the Wii-style vertical panel navigation. The silver top/bottom bars
// stay fixed; only the colored panels (green header + blue body) slide within
// the viewport, non-looping. The bars' ▲/▼ labels update to the neighbouring
// panels. Also responds to the Up/Down arrow keys.
export default class extends Controller {
  static targets = ["track", "panel", "title", "prevControl", "prevLabel", "nextControl", "nextLabel"]
  static values = { default: String }

  connect() {
    const start = this.panelTargets.findIndex((p) => p.dataset.panel === this.defaultValue)
    this.index = start < 0 ? 0 : start

    // Jump to the default panel without animating on first paint.
    this.trackTarget.style.transition = "none"
    this.#render()
    this.trackTarget.offsetHeight // force reflow so the jump is applied
    this.trackTarget.style.transition = ""

    this.onKeydown = (event) => {
      if (event.key === "ArrowUp") { this.prev(); event.preventDefault() }
      else if (event.key === "ArrowDown") { this.next(); event.preventDefault() }
    }
    window.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
  }

  prev() {
    if (this.index > 0) { this.index--; this.#render() }
  }

  next() {
    if (this.index < this.panelTargets.length - 1) { this.index++; this.#render() }
  }

  #render() {
    const active = this.panelTargets[this.index]
    this.trackTarget.style.transform = `translateY(-${this.index * 100}%)`
    this.element.dataset.activePanel = active?.dataset.panel
    this.titleTarget.textContent = active?.dataset.title

    this.#updateControl(this.prevControlTarget, this.prevLabelTarget, this.panelTargets[this.index - 1])
    this.#updateControl(this.nextControlTarget, this.nextLabelTarget, this.panelTargets[this.index + 1])
  }

  #updateControl(control, label, neighbour) {
    if (neighbour) {
      label.textContent = neighbour.dataset.title
      control.hidden = false
    } else {
      control.hidden = true
    }
  }
}
