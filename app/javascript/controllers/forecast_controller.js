import { Controller } from "@hotwired/stimulus"

// Drives the Wii-style vertical panel navigation. The silver top/bottom bars
// stay fixed; only the colored panels (green header + blue body) slide within
// the viewport, non-looping. The bars' ▲/▼ labels update to the neighbouring
// panels. Also responds to the Up/Down arrow keys.
//
// One panel — the last, marked data-forecast-secret — is in the track but not
// in the stack: navigation stops one short of it until somebody pushes past
// the end three times running, which is the only gesture on this screen that
// otherwise does nothing at all. Once found it stays found, the way the
// jukebox remembers being muted.
const UNLOCK_KEY = "forecastCredits"
const UNLOCK_SHOVES = 3

export default class extends Controller {
  static targets = ["track", "panel", "title", "prevControl", "prevLabel", "nextControl", "nextLabel"]
  static values = { default: String }

  connect() {
    const start = this.panelTargets.findIndex((p) => p.dataset.panel === this.defaultValue)
    this.index = start < 0 ? 0 : start

    // Before the first #render, so an unlocked reader's ▼ is already offering
    // the panel rather than lighting up a moment later.
    this.unlocked = this.#readUnlocked()
    this.shoves = 0

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

    // Turning back abandons the attempt, so finding the secret panel is three
    // shoves in a row rather than three accidents over an afternoon.
    this.shoves = 0
    if (this.index > 0) { this.index--; this.#render() }
  }

  next() {
    if (this.#dismissOverlay()) return

    if (this.index < this.#lastIndex()) { this.index++; this.#render(); return }

    this.#shove()
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

  // The last panel anyone can reach: the end of the track, unless the secret
  // panel is down there still locked, in which case one short of it.
  #lastIndex() {
    const last = this.panelTargets.length - 1
    const secret = this.panelTargets[last]?.hasAttribute("data-forecast-secret")

    return secret && !this.unlocked ? last - 1 : last
  }

  // Pushing at the dead end. Three in a row opens the panel below it.
  //
  // Only the arrow keys and a swipe get here: at the end the ▼ button is
  // disabled, and a disabled button fires no click. That's the right shape for
  // a secret — it isn't reachable by idly clicking the thing that looks broken
  // — but it isn't obvious from the code, hence this.
  #shove() {
    this.#nudge() // every dead end gives a little, whether or not one hides something

    if (this.#lastIndex() === this.panelTargets.length - 1) return // nothing hidden

    this.shoves++
    if (this.shoves < UNLOCK_SHOVES) return

    this.shoves = 0
    this.unlocked = true
    this.#storeUnlocked()
    this.index++
    this.#render()
  }

  // A short give-and-return on the track, so pushing at the end feels like
  // pushing at something rather than like nothing happening. Removed on
  // animationend and restarted through a reflow, the same one-shot trick the
  // press controller uses on the bar buttons.
  #nudge() {
    const track = this.trackTarget
    track.classList.remove("is-nudged")
    void track.offsetWidth
    track.classList.add("is-nudged")
    track.addEventListener("animationend", () => track.classList.remove("is-nudged"), { once: true })
  }

  #readUnlocked() {
    try {
      return window.localStorage.getItem(UNLOCK_KEY) === "1"
    } catch {
      return false
    }
  }

  #storeUnlocked() {
    try {
      window.localStorage.setItem(UNLOCK_KEY, "1")
    } catch {
      // Storage denied: they still get the panel, just not next time.
    }
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

    // Through the limit, not straight at panelTargets: reaching the 5-Day panel
    // must not label the ▼ "Credits". This is the one line the secret leaks
    // through if it's got wrong.
    const below = this.index + 1 <= this.#lastIndex() ? this.panelTargets[this.index + 1] : null

    this.#updateControl(this.prevControlTarget, this.prevLabelTarget, this.panelTargets[this.index - 1])
    this.#updateControl(this.nextControlTarget, this.nextLabelTarget, below)
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
