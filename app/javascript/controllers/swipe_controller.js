import { Controller } from "@hotwired/stimulus"

// Turns a finger drag into a direction, and leaves what that means to whoever
// listens:
//
//   data-controller="forecast press swipe"
//   data-action="swipe:up->forecast#next swipe:down->forecast#prev"
//
// The pointer maths stays out of the controller that owns the panel state, the
// same way `press` and `sixhour` are separate behaviours composed onto these
// elements rather than folded into `forecast`.
//
// Touch and pen only. A mouse drag across a panel does nothing today, and
// making it navigate would mean an accidental drag moved the screen *and* the
// click suppression below swallowed a click the reader meant to make. Desktop
// already has the ▲/▼ buttons and the arrow keys.
//
// Not handled on purpose: the wheel/trackpad (the arrow keys are the desktop
// answer), and dragging the panels live under the finger — that one would be
// the more Wii-like micro-interaction, but it needs the forecast controller to
// expose a drag/release API, drop its transition mid-drag and rubber-band at
// the ends, so it isn't this.
const POINTER_TYPES = [ "touch", "pen" ]

// How far the dominant axis has to travel to count. Around 7% of a phone's
// height: past the wobble in a tap, short of a deliberate flick.
const MIN_DISTANCE = 50

// ...and how far it has to beat the other axis by, so a diagonal drag doesn't
// fire the wrong one. 1.6 is roughly "within 32° of the axis".
const DOMINANCE = 1.6

export default class extends Controller {
  connect() {
    this.onPointerDown = this.onPointerDown.bind(this)
    this.onPointerUp = this.onPointerUp.bind(this)
    this.onPointerCancel = this.onPointerCancel.bind(this)

    this.element.addEventListener("pointerdown", this.onPointerDown)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPointerDown)
    this.#endGesture()
  }

  onPointerDown(event) {
    if (!POINTER_TYPES.includes(event.pointerType)) return

    // A second finger means a pinch, not a swipe.
    if (this.start && event.isPrimary === false) return this.#endGesture()

    this.start = { x: event.clientX, y: event.clientY }

    // On window rather than the element: a finger that slides off the edge
    // still has to end the gesture. Deliberately not setPointerCapture, which
    // would do the same job but retarget the events — and `click`'s target is
    // derived from the pointerdown/pointerup targets, so capturing here would
    // risk every click being reported against this element instead of the
    // button under the finger, breaking `press`'s button lookup and the ▲/▼
    // actions. That's the same trap press_controller's click-not-pointerdown
    // comment is about.
    window.addEventListener("pointerup", this.onPointerUp)
    window.addEventListener("pointercancel", this.onPointerCancel)
  }

  onPointerUp(event) {
    const start = this.start
    this.#endGesture()
    if (!start) return

    const x = event.clientX - start.x
    const y = event.clientY - start.y
    const direction = this.#direction(x, y)
    if (!direction) return

    this.#suppressClick()
    this.dispatch(direction) // → "swipe:up" / "swipe:down" / "swipe:left" / "swipe:right"
  }

  onPointerCancel() {
    this.#endGesture()
  }

  // The dominant axis, if it went far enough and beat the other by enough.
  // Null for a tap, a slow wander, or anything too diagonal to read.
  #direction(x, y) {
    const [ across, along ] = [ Math.abs(x), Math.abs(y) ]

    if (along >= MIN_DISTANCE && along > across * DOMINANCE) return y < 0 ? "up" : "down"
    if (across >= MIN_DISTANCE && across > along * DOMINANCE) return x < 0 ? "left" : "right"
    return null
  }

  // A finger drag still ends in a click, so without this a swipe across the
  // Today panel would also toggle its 6-hour overlay. Capture on window is the
  // first thing in the propagation path, so the event never reaches the zone's
  // own click action (or `press`, which is right — no button was pressed).
  // preventDefault as well, because a swipe that began on a bar would otherwise
  // follow the link under it.
  #suppressClick() {
    const swallow = (event) => {
      event.stopPropagation()
      event.preventDefault()
    }

    window.addEventListener("click", swallow, { capture: true, once: true })

    // Torn down at the end of this turn rather than after a grace period: the
    // compatibility click follows pointerup before the browser yields, so a
    // timer of zero still catches it — and a gesture that produced no click at
    // all can't then leave a listener lying in wait for the next real tap,
    // however soon it comes.
    setTimeout(() => window.removeEventListener("click", swallow, { capture: true }))
  }

  #endGesture() {
    this.start = null
    window.removeEventListener("pointerup", this.onPointerUp)
    window.removeEventListener("pointercancel", this.onPointerCancel)
  }
}
