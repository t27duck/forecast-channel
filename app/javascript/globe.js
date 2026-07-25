// The map page's own bundle. mapbox-gl is ~90% of the JavaScript weight and
// only the globe wants it, so its controller stays out of application.js and
// ships here instead — every top-level file in app/javascript is an esbuild
// entry point, so this file being here is the whole of that arrangement. It
// keeps the bundle every other page loads at ~40KB gzipped rather than ~560KB.
//
// Two things this depends on: maps/show is the only view that includes it, and
// it includes it *after* the main bundle, since that's what defines
// window.Stimulus. Registering here rather than in controllers/index.js is what
// javascript_bundles_test.rb checks — a stimulus:manifest:update undoes it.

import GlobeController from "./controllers/globe_controller"

window.Stimulus.register("globe", GlobeController)
