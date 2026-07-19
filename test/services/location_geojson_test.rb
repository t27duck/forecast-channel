require "test_helper"

class LocationGeojsonTest < ActiveSupport::TestCase
  test "each feature carries current, today and tomorrow icons from the codes" do
    location = Location.new(
      name: "Testville", latitude: 1.0, longitude: 2.0,
      current_condition_code: 3,             # overcast
      today_forecast: { "condition_code" => 61 },   # rain
      tomorrow_forecast: { "condition_code" => 71 }  # snow
    )

    props = LocationGeojson.feature(location)[:properties]
    assert_equal "overcast", props[:icon]
    assert_equal "rain", props[:icon_today]
    assert_equal "snow", props[:icon_tomorrow]
  end

  test "a missing daily forecast falls back to the current icon" do
    location = Location.new(
      name: "Testville", latitude: 1.0, longitude: 2.0,
      current_condition_code: 3, today_forecast: {}, tomorrow_forecast: nil
    )

    props = LocationGeojson.feature(location)[:properties]
    assert_equal "overcast", props[:icon_today]
    assert_equal "overcast", props[:icon_tomorrow]
  end
end
