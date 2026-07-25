require "application_system_test_case"

class GeolocationTest < ApplicationSystemTestCase
  # The happy path (detecting the nearest location) needs a secure origin
  # (HTTPS/localhost), which the HTTP test server isn't — the browser refuses
  # to locate here. The server side is covered by
  # CurrentLocationsControllerTest; this checks the picker says so and leaves
  # the list as the way forward.
  test "the picker offers geolocation and explains when the browser refuses" do
    visit settings_location_path

    assert_selector ".picker__row--locate", text: "Use My Current Location"

    click_button "Use My Current Location"

    assert_selector ".picker__notice", text: /couldn't get your location/, wait: 15
    assert_selector ".picker__row", text: locations(:berlin).country # still pickable by hand
  end

  test "the geolocation row is offered only when choosing a country" do
    visit settings_location_path(country: locations(:berlin).country)

    assert_no_selector ".picker__row--locate"
  end
end
