// Registers the service worker (app/views/pwa/service-worker.js.erb), which
// keeps the last forecast readable with no network. A side-effect module, like
// ./stream_actions beside it.
//
// The path is written out rather than derived, the same way globe_controller
// hand-builds "/locations/${slug}" — both sides change together, and
// test/integration/pwa_test.rb asserts this exact literal so a route rename
// fails loudly instead of quietly leaving every visitor unregistered.
const PATH = "/service-worker"

// Skipped under test automation, and the feature check doesn't cover it. A
// worker needs a secure context, and this suite is driven two ways: locally
// over plain http to the `rails-app` host, where navigator.serviceWorker
// doesn't exist at all, and in CI against 127.0.0.1, which *is* a secure
// origin. So without this the worker would register in CI and not locally —
// the same split test/system/geolocation_test.rb already works around.
//
// What that would cost isn't a failing test but a flaky one: the worker claims
// the origin, caches "/" and the forecasts, and a later example gets served an
// earlier example's HTML from a cache that knows nothing about the database
// being rolled back between them. It would read as a Turbo morph bug.
//
// Gating on production instead would be worse in the other direction: the
// worker would only ever run where it can't be debugged, so its bugs would ship.
// In development it registers, and stays workable by construction — an edited
// worker takes over on the next reload (skipWaiting + clients.claim), any
// JS/CSS edit rotates the cache (the version follows the asset digests), and
// pages are fetched network-first so ERB edits show up straight away. The one
// thing to know: with `bin/dev` stopped, "/" and the last forecast still load
// from cache, which can look convincingly like a running server. DevTools →
// Application → Service workers → Update on reload, or Unregister.
if ("serviceWorker" in navigator && !navigator.webdriver) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register(PATH).catch((error) => {
      console.warn("[pwa] service worker registration failed", error)
    })
  })
}
