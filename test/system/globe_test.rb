require "application_system_test_case"

class GlobeTest < ApplicationSystemTestCase
  setup { choose_location(locations(:berlin)) } # the globe is gated on having one

  test "renders the globe and adds the location markers layer" do
    visit map_path

    # The globe controller sets data-map-ready once the style has loaded and the
    # symbol layer (which renders markers in WebGL, not the DOM) has been added.
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    layer_present = evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('[data-controller=globe]')
        return !!(el && el.__map && el.__map.getLayer('location-markers'))
      })()
    JS
    assert layer_present, "expected the location-markers symbol layer to exist"
  end

  test "the globe builds without a Mapbox token, reaching nothing on the network" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    # The test environment blanks the token (config/environments/test.rb), so
    # this is the same path CI takes: the controller's offline style.
    assert_equal "", find("[data-controller=globe]")["data-globe-token-value"]

    fetched = evaluate_script(
      "performance.getEntriesByType('resource').map((e) => e.name).filter((n) => n.includes('mapbox.com'))"
    )
    assert_empty fetched, "expected the globe to render without calling Mapbox"
  end

  test "the zoom-in button zooms the globe in one unit" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    wake_chrome
    zoom = -> { evaluate_script("#{map_handle}.getZoom()") }
    before = zoom.call
    find(".map-bar [aria-label='Zoom in']").click

    # zoomIn animates, so poll until the zoom settles ~one unit higher.
    assert_equal true, wait_until { zoom.call > before + 0.5 }, "expected the globe to zoom in"
  end

  test "the Next button cycles the marker view banner" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    wake_chrome
    assert_selector ".map-banner", text: "CURRENT WEATHER" # uppercased in CSS
    find(".map-bar [aria-label='Next weather view']").click
    assert_selector ".map-banner", text: "TODAY'S WEATHER"
    find(".map-bar [aria-label='Next weather view']").click
    assert_selector ".map-banner", text: "TOMORROW'S WEATHER"
    find(".map-bar [aria-label='Next weather view']").click
    assert_selector ".map-banner", text: "CURRENT WEATHER" # wraps back around
  end

  test "the tilt buttons pitch the globe and Restore resets it" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    wake_chrome
    pitch = -> { evaluate_script("#{map_handle}.getPitch()") }
    assert_equal 0, pitch.call # starts flat, so decreasing is disabled
    assert_selector ".map-bar [aria-label='Decrease tilt']:disabled"

    find(".map-bar [aria-label='Increase tilt']").click
    assert_equal true, wait_until { pitch.call > 5 }, "expected the globe to tilt"

    find(".map-bar button", text: "Restore").click
    assert_equal true, wait_until { pitch.call.zero? }, "expected Restore to reset the tilt"
  end

  test "the map saves its camera view when it is moved" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 20

    wake_chrome
    find(".map-bar [aria-label='Zoom in']").click
    sleep 0.8 # let the zoom animation settle and moveend save the view

    saved = evaluate_script("JSON.parse(window.sessionStorage.getItem('globeCamera') || 'null')")
    refute_nil saved, "expected the view to be saved on move"
    assert_operator saved["zoom"], :>, 7.5
  end

  test "with nothing to go on the map falls back to New York" do
    # No ?location focus and nothing saved, so only the built-in default is left.
    visit location_path(locations(:berlin)) # same origin, to reach sessionStorage
    execute_script("window.sessionStorage.removeItem('globeCamera')")

    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 20

    center = evaluate_script("document.querySelector('[data-controller=globe]').__map.getCenter()")
    assert_in_delta(-74.00597, center["lng"], 0.01)
    assert_in_delta 40.71427, center["lat"], 0.01
  end

  test "the map resumes the camera view it was last left at" do
    # Stand in for having left the map zoomed to a particular spot.
    # Same origin, no WebGL — just to reach sessionStorage.
    visit location_path(locations(:berlin))
    execute_script(
      "window.sessionStorage.setItem('globeCamera', " \
      "JSON.stringify({ center: [12, 48], zoom: 5.5, pitch: 0, bearing: 0 }))"
    )

    visit map_path # no ?location focus, so it resumes the saved view
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 20
    restored = evaluate_script("document.querySelector('[data-controller=globe]').__map.getZoom()")
    assert_in_delta 5.5, restored, 0.05
  end

  test "the globe shows the open hand, and a fist while it is dragged" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 20

    wake_chrome # an idle pointer hides the cursor entirely
    canvas_cursor = -> { style(".mapboxgl-canvas-container", "cursor") }
    assert_match "open-hand-1", canvas_cursor.call
    assert_match "point-1", evaluate_script("getComputedStyle(document.body).cursor") # bars, page chrome

    execute_script("#{map_handle}.fire('dragstart')")
    assert_match "grab-1", canvas_cursor.call

    execute_script("#{map_handle}.fire('dragend')")
    assert_match "open-hand-1", canvas_cursor.call
  end

  test "the chrome gets out of the way while the mouse is idle" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    # Nothing has moved the pointer since the page opened, so it idles on its own.
    assert_selector ".map-view.is-idle", wait: 5
    assert_equal "none", style(".map-view", "cursor"), "expected the cursor to be hidden"
    assert_equal "none", style(".mapboxgl-canvas-container", "cursor")
    assert_equal true, wait_until { style(".map-banner", "opacity") == "0" },
      "expected the banner to fade out"

    viewport = evaluate_script("window.innerHeight")
    assert_equal true, wait_until { edge(".map-bar--top", "bottom") <= 0 },
      "expected the top bar to slide off the top of the page"
    assert_equal true, wait_until { edge(".map-bar--bottom", "top") >= viewport },
      "expected the bottom bar to slide off the bottom of the page"
  end

  test "moving the mouse brings the chrome back" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15
    assert_selector ".map-view.is-idle", wait: 5

    page.driver.browser.action.move_to(find(".map-view").native).perform

    assert_no_selector ".map-view.is-idle"
    assert_match "open-hand-1", style(".mapboxgl-canvas-container", "cursor")
    assert_equal true, wait_until { style(".map-banner", "opacity").to_f > 0.99 },
      "expected the banner to fade back in"
  end

  test "the idle globe turns on its own once it is zoomed right out" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    # Zoom 2 is the widest view; the drift only starts there.
    park_globe_at(zoom: 2)
    longitude = -> { evaluate_script("#{map_handle}.getCenter().lng") }
    start = longitude.call

    assert_equal true, wait_until { longitude.call < start - 0.5 },
      "expected the idle globe to drift westward"

    # ...and settles the moment the mouse comes back.
    page.driver.browser.action.move_to(find(".map-view").native).perform
    stopped = longitude.call
    sleep 0.6
    assert_in_delta stopped, longitude.call, 0.05, "expected the spin to stop on wake"
  end

  test "the idle globe stays put when it is zoomed in" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    park_globe_at(zoom: 5)
    longitude = -> { evaluate_script("#{map_handle}.getCenter().lng") }
    start = longitude.call
    sleep 1.5 # long enough for a spin step to have moved it

    assert_in_delta start, longitude.call, 0.05, "expected no drift while zoomed in"
  end

  private

  # The chrome hides itself after two idle seconds, and a driver click can't
  # reach a bar that has slid off the page. A real pointer move brings it back
  # the way a viewer's would; wait for the slide to finish before clicking.
  def wake_chrome
    page.driver.browser.action.move_to(find(".map-view").native).perform
    assert_no_selector ".map-view.is-idle"
    assert_equal true, wait_until { edge(".map-bar--top", "top") >= -0.5 },
      "expected the top bar to slide back into place"
  end

  # Put the globe at a known camera the way a viewer would leave it: wake first
  # (which stops any drift already under way), move, then let it idle again.
  def park_globe_at(zoom:)
    page.driver.browser.action.move_to(find(".map-view").native).perform
    assert_no_selector ".map-view.is-idle"
    execute_script("#{map_handle}.jumpTo({ center: [0, 20], zoom: #{zoom} })")
    assert_selector ".map-view.is-idle", wait: 5
  end

  def map_handle
    "document.querySelector('[data-controller=globe]').__map"
  end

  def style(selector, property)
    evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  def edge(selector, side)
    evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().#{side}")
  end

  # Polls the block until it returns truthy or Capybara's default wait elapses.
  def wait_until
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        result = yield
        return result if result

        sleep 0.1
      end
    end
  rescue Timeout::Error
    false
  end
end
