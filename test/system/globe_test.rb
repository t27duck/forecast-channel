require "application_system_test_case"

class GlobeTest < ApplicationSystemTestCase
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

  test "the zoom-in button zooms the globe in one unit" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

    zoom = -> { evaluate_script("document.querySelector('[data-controller=globe]').__map.getZoom()") }
    before = zoom.call
    find(".map-bar [aria-label='Zoom in']").click

    # zoomIn animates, so poll until the zoom settles ~one unit higher.
    assert_equal true, wait_until { zoom.call > before + 0.5 }, "expected the globe to zoom in"
  end

  test "the Next button cycles the marker view banner" do
    visit map_path
    assert_selector "[data-controller=globe][data-map-ready=true]", wait: 15

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

    pitch = -> { evaluate_script("document.querySelector('[data-controller=globe]').__map.getPitch()") }
    assert_equal 0, pitch.call # starts flat, so decreasing is disabled
    assert_selector ".map-bar [aria-label='Decrease tilt']:disabled"

    find(".map-bar [aria-label='Increase tilt']").click
    assert_equal true, wait_until { pitch.call > 5 }, "expected the globe to tilt"

    find(".map-bar button", text: "Restore").click
    assert_equal true, wait_until { pitch.call.zero? }, "expected Restore to reset the tilt"
  end

  private

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
