import { Controller } from "@hotwired/stimulus"

// Watches for a secret key sequence and, when one lands, says so — leaving what
// it *means* to whoever listens:
//
//   data-controller="globe sequence"
//   data-sequence-keys-value="ArrowUp ArrowUp ArrowDown ..."
//   data-action="sequence:matched->globe#toggleProjection"
//
// The same division of labour as `swipe`: the input handling stays out of the
// controller that owns the state, and the wiring is where the gesture acquires
// a meaning. That also gets this across the bundle split for free — Stimulus
// resolves a `data-action` by identifier against the one `window.Stimulus`
// application, so this (in the main bundle) can drive a method on `globe` (in
// its own) without either importing the other.
export default class extends Controller {
  static values = { keys: String }

  connect() {
    this.keys = this.keysValue.toLowerCase().split(/\s+/).filter(Boolean)
    this.recent = []

    this.onKeydown = this.onKeydown.bind(this)
    window.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    // Deliberately neither preventDefault nor stopPropagation. Every screen
    // this can ride on has key handlers of its own — the globe wakes its chrome
    // on any key and stops a tour on Escape, the forecast moves on the arrows —
    // and a detector that quietly ate their input would be a bug hunted from
    // entirely the wrong end.
    if (event.repeat || event.metaKey || event.ctrlKey || event.altKey) return
    if (this.keys.length === 0) return

    // A rolling window of the last few keys, compared whole, rather than a
    // cursor stepped forward and reset on a wrong key. The two agree on a clean
    // run and differ on a fumbled one: with a cursor, an extra ↑ at the front
    // of ↑↑↓↓… puts the run permanently out of phase and it can never recover.
    // Here the stray key simply falls off the back of the window.
    this.recent.push(event.key.toLowerCase())
    if (this.recent.length > this.keys.length) this.recent.shift()
    if (this.recent.length < this.keys.length) return
    if (!this.recent.every((key, i) => key === this.keys[i])) return

    this.recent = []
    this.dispatch("matched") // → "sequence:matched"
  }
}
