require "test_helper"

# mapbox-gl is ~90% of the JavaScript weight and only the map page wants it, so
# the globe controller is kept out of the main bundle and ships as its own
# esbuild entry (app/javascript/globe.js), included by maps/show alone.
#
# That arrangement is easy to undo without noticing: `bin/rails
# stimulus:manifest:update` regenerates controllers/index.js and puts the globe
# controller straight back, which silently returns Mapbox to every page. These
# tests fail when it does.
class JavascriptBundlesTest < ActiveSupport::TestCase
  # Reading the build output unconditionally is safe: the suite already needs a
  # build, since javascript_include_tag raises without one.
  BUILDS = Rails.root.join("app/assets/builds")
  JAVASCRIPT = Rails.root.join("app/javascript")

  # Each assertion tests a boolean rather than using assert_includes, whose
  # failure output prints the haystack — here, a multi-megabyte bundle.
  test "the main bundle every page loads carries no Mapbox" do
    assert_not BUILDS.join("application.js").read.include?("mapbox-gl"),
      "mapbox-gl is back in application.js, so every page pays for it again — " \
      "check whether controllers/index.js registers the globe controller"
  end

  test "the globe bundle is where Mapbox lives" do
    assert BUILDS.join("globe.js").read.include?("mapbox-gl"),
      "globe.js should bundle mapbox-gl; the split is pointless otherwise"
  end

  test "the globe controller registers from its own entry, not the manifest" do
    assert_not JAVASCRIPT.join("controllers/index.js").read.include?("globe_controller"),
      "controllers/index.js registers the globe controller again (a " \
      "stimulus:manifest:update will do this); it belongs in globe.js"
    assert JAVASCRIPT.join("globe.js").read.include?("globe_controller"),
      "globe.js should be what registers the globe controller"
  end
end
