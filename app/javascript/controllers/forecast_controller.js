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

    // Hold the chrome out of a refresh morph. Turbo asks before each element,
    // and a cancelled answer skips that element and everything under it — so
    // the bars and header keep the state JavaScript put there (see
    // locations/show for what, and why data-turbo-permanent is the wrong tool).
    this.onBeforeMorph = (event) => {
      if (event.target.hasAttribute("data-forecast-frozen")) event.preventDefault()
    }
    document.addEventListener("turbo:before-morph-element", this.onBeforeMorph)

    // What the morph does still reach is the panels, whose markup always
    // arrives scrolled to the default. Only the position needs putting back.
    this.onMorph = () => this.#position()
    document.addEventListener("turbo:morph", this.onMorph)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-morph-element", this.onBeforeMorph)
    document.removeEventListener("turbo:morph", this.onMorph)
  }

  prev() {
    if (this.#dismissOverlay()) return
    if (this.index > 0) { this.index--; this.#render() }
  }

  next() {
    if (this.#dismissOverlay()) return
    if (this.index < this.panelTargets.length - 1) { this.index++; this.#render() }
  }

  // While the 6-hour breakdown is up, the first move backs out of it instead of
  // sliding it off screen still open — which would also strand its weekday in
  // the frozen header, over a panel it has nothing to do with. The ▼ label
  // still names the next panel, so a move that only closes the overlay reads
  // as a step back rather than as nothing happening; a second one goes.
  //
  // Here rather than in each caller so the rule is the same whichever way the
  // reader moves: the ▲/▼ buttons, the arrow keys, or a swipe.
  #dismissOverlay() {
    if (!this.element.querySelector(".wii-sixhour-zone.is-open")) return false

    this.dispatch("dismiss", { target: window }) // → "forecast:dismiss"
    return true
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
