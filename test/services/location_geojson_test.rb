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

  test "each feature carries the weather shown in the hover popup" do
    location = Location.new(
      name: "Testville", latitude: 1.0, longitude: 2.0,
      current_temperature: 18.5, current_condition_label: "Overcast",
      today_forecast: { "high" => 21, "low" => 12, "condition_label" => "Light rain" },
      tomorrow_forecast: { "high" => 8, "low" => 1, "condition_label" => "Snow" }
    )

    props = LocationGeojson.feature(location)[:properties]
    assert_equal 19, props[:temp] # 18.5°C rounded; the client converts the unit
    assert_equal "Overcast", props[:label]
    assert_equal 21, props[:today_high]
    assert_equal 12, props[:today_low]
    assert_equal "Light rain", props[:today_label]
    assert_equal 8, props[:tomorrow_high]
    assert_equal "Snow", props[:tomorrow_label]
  end

  test "weather popup fields are nil when the forecast is missing" do
    location = Location.new(
      name: "Testville", latitude: 1.0, longitude: 2.0,
      today_forecast: {}, tomorrow_forecast: nil
    )

    props = LocationGeojson.feature(location)[:properties]
    assert_nil props[:temp]
    assert_nil props[:today_high]
    assert_nil props[:tomorrow_label]
  end

  test "the current icon goes to its night variant after dark, but the day's forecast stays a day icon" do
    london = Location.new(name: "London", latitude: 51.5, longitude: -0.13, current_condition_code: 0)

    # Midnight UTC is the middle of the night in London.
    travel_to Time.utc(2026, 7, 20, 0, 0, 0) do
      props = LocationGeojson.feature(london)[:properties]
      assert_equal "clear_night", props[:icon]
      assert_equal "clear", props[:icon_today], "a missing day forecast falls back to the day icon, not the moon"
    end

    # Noon UTC is daytime in London: the plain clear icon.
    travel_to Time.utc(2026, 7, 20, 12, 0, 0) do
      assert_equal "clear", LocationGeojson.feature(london)[:properties][:icon]
    end
  end

  # The globe's feed selects only COLUMNS, so anything feature/1 reads that
  # isn't listed raises MissingAttributeError in production and nowhere else.
  test "COLUMNS lists every column a feature reads" do
    location = Location.create!(name: "Testville", latitude: 1.0, longitude: 2.0,
      current_condition_code: 3, population: 100)
    slim = Location.select(LocationGeojson::COLUMNS).find(location.id)

    assert_nothing_raised { LocationGeojson.feature(slim) }
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
