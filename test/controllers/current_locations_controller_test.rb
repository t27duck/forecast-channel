require "test_helper"

class CurrentLocationsControllerTest < ActionDispatch::IntegrationTest
  test "create sets the nearest location and shows its forecast" do
    # Coordinates near Tokyo resolve to the Tokyo fixture.
    post current_location_url, params: { latitude: 35.0, longitude: 139.0 }

    assert_redirected_to root_path
    assert_equal locations(:tokyo).id.to_s, cookies[:current_location_id]
  end

  test "create without coordinates leaves the cookie unset" do
    post current_location_url, params: {}

    assert_redirected_to root_path
    assert_predicate cookies[:current_location_id], :blank?
  end
end
