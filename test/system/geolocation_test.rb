require "application_system_test_case"

class GeolocationTest < ApplicationSystemTestCase
  # The happy path (detecting the nearest location) needs a secure origin
  # (HTTPS/localhost), which the HTTP test server isn't — the browser blocks
  # geolocation here. The server side is covered by
  # CurrentLocationsControllerTest; this checks the page degrades gracefully
  # when geolocation is unavailable.
  test "falls back to the default location when geolocation is unavailable" do
    visit root_path

    assert_selector "[data-controller=geolocate]", visible: :all # asked to locate
    assert_selector ".wii-header__location", text: locations(:berlin).name # default still renders
    assert_selector "[data-controller=forecast]"
  end
end
