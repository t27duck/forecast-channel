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

    // locations/show already renders this state, so on a cold load this is a
    // no-op. It still matters on a Turbo restore visit, whose cached snapshot
    // carries the inline transform of whatever panel the visitor left on —
    // jump back to the default without animating.
    this.trackTarget.style.transition = "none"
    this.#render()
    this.trackTarget.offsetHeight // force reflow so the jump is applied
    this.trackTarget.style.transition = ""

    this.onKeydown = (event) => {
      if (event.key === "ArrowUp") { this.prev(); event.preventDefault() }
      else if (event.key === "ArrowDown") { this.next(); event.preventDefault() }
    }
    window.addEventListener("keydown", this.onKeydown)

    // A weather refresh re-requests this page and morphs the panels in, which
    // puts the server's markup — always the default panel — back over the
    // track. Only the position needs restoring: the bars and header are
    // data-turbo-permanent, so the morph never reached them.
    this.onMorph = () => this.#position()
    document.addEventListener("turbo:morph", this.onMorph)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:morph", this.onMorph)
  }

  prev() {
    if (this.index > 0) { this.index--; this.#render() }
  }

  next() {
    if (this.index < this.panelTargets.length - 1) { this.index++; this.#render() }
  }

  #render() {
    this.#position()
    this.#chrome()
  }

  // Where the track sits — the only part a morph can disturb.
  #position() {
    this.trackTarget.style.transform = `translateY(-${this.index * 100}%)`
    this.element.dataset.activePanel = this.panelTargets[this.index]?.dataset.panel
  }

  // The fixed header and bar labels. Kept apart from the position so a morph
  // doesn't re-run it: the 6-hour overlay may have put a weekday in the title,
  // and restoring the panel name over it would undo that.
  #chrome() {
    const active = this.panelTargets[this.index]
    this.titleTarget.textContent = active?.dataset.title

    this.#updateControl(this.prevControlTarget, this.prevLabelTarget, this.panelTargets[this.index - 1])
    this.#updateControl(this.nextControlTarget, this.nextLabelTarget, this.panelTargets[this.index + 1])
  }

  // Keep the arrow button in place at the ends — just disable it (greyed,
  // label cleared) so the whole button never disappears from the bar.
  #updateControl(control, label, neighbour) {
    const glyph = control.querySelector("span.wii-arrow__glyph")
    if (neighbour) {
      label.textContent = neighbour.dataset.title
      control.disabled = false
      glyph.classList.remove("hidden")
    } else {
      label.textContent = ""
      control.disabled = true
      glyph.classList.add("hidden")
    }
  }
}
