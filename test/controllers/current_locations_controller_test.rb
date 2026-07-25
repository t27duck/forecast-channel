require "test_helper"

class CurrentLocationsControllerTest < ActionDispatch::IntegrationTest
  test "create sets the nearest location and returns to settings" do
    # Coordinates near Tokyo resolve to the Tokyo fixture.
    post current_location_url, params: { latitude: 35.0, longitude: 139.0 }

    assert_redirected_to settings_path
    assert_equal locations(:tokyo).id, read_signed_cookie(:current_location_id)
  end

  test "create seeds the units of the country it lands in" do
    Location.create!(name: "Austin", country: "United States", country_code: "US",
      admin1: "Texas", latitude: 30.27, longitude: -97.74)

    post current_location_url, params: { latitude: 30.3, longitude: -97.7 }

    assert_equal "fahrenheit", read_signed_cookie(:temperature_unit)
    assert_equal "mph", read_signed_cookie(:wind_unit)
  end

  test "create returns to the picker when there are no coordinates" do
    post current_location_url, params: {}

    assert_redirected_to settings_location_path
    assert_nil read_signed_cookie(:current_location_id)
  end
end
