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
end
