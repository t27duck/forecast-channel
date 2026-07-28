// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
// After turbo-rails, which is what defines the Turbo global they register on.
import "./lib/stream_actions"
import "./controllers"
