// Custom Turbo Stream actions, registered on the Turbo global that
// `@hotwired/turbo-rails` sets up (see application.js).
//
// The app broadcasts *signals*, not markup. It has to: every weather view
// renders through `current_setting`, which reads the visitor's own signed
// temperature/wind cookies, and a broadcast renders with no request and no
// cookies — so streaming rendered HTML would push one visitor's units onto
// everyone. Instead the server says "this changed", and the client re-fetches
// over HTTP, where its cookies apply.
//
// Each action turns the <turbo-stream> element into a window CustomEvent. Going
// through the window (rather than calling into a controller) is what lets the
// globe controller listen from its own bundle — globe.js is built separately so
// mapbox-gl stays out of the main one, and neither bundle can import from the
// other.
import { Turbo } from "@hotwired/turbo-rails"

// Weather was refreshed for some batch of locations: anything showing many
// locations at once (the globe) should re-read its feed.
export const WEATHER_REFRESHED = "forecast:weather-refreshed"

// One location's refresh finished — the splash is waiting on this to hand over.
export const WEATHER_READY = "forecast:weather-ready"

// `version` is a cache-buster the listener appends to its re-fetch, so a
// conditional GET can't hand back the bytes we just invalidated.
Turbo.StreamActions.weather_refreshed = function () {
  dispatch(WEATHER_REFRESHED, { version: this.getAttribute("version") })
}

Turbo.StreamActions.weather_ready = function () {
  dispatch(WEATHER_READY, { slug: this.getAttribute("slug") })
}

function dispatch(name, detail) {
  window.dispatchEvent(new CustomEvent(name, { detail }))
}
