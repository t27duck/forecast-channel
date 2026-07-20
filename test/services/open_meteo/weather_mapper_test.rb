require "test_helper"

class OpenMeteo::WeatherMapperTest < ActiveSupport::TestCase
  setup do
    @attributes = OpenMeteo::WeatherMapper.new(open_meteo_forecast_payload).attributes
  end

  test "maps current conditions with labels" do
    assert_in_delta 21.4, @attributes[:current_temperature]
    assert_equal 3, @attributes[:current_condition_code]
    assert_equal "Overcast", @attributes[:current_condition_label]
    assert_in_delta 5.2, @attributes[:uv_index]
    assert_equal "Moderate", @attributes[:uv_label]
    assert_not_nil @attributes[:weather_refreshed_at]
  end

  test "maps current humidity and precipitation probability for the laundry index" do
    assert_equal 68, @attributes[:current_humidity]
    assert_equal 20, @attributes[:current_precipitation_probability]
  end

  test "maps current and daily wind" do
    assert_in_delta 18.3, @attributes[:current_wind_speed]
    assert_equal 160, @attributes[:current_wind_direction]
    assert_in_delta 24.0, @attributes[:today_forecast]["wind_speed"]
    assert_equal 135, @attributes[:today_forecast]["wind_direction"]
    assert_in_delta 20.5, @attributes[:tomorrow_forecast]["wind_speed"]
    assert_equal 200, @attributes[:tomorrow_forecast]["wind_direction"]
  end

  test "maps today and tomorrow highs, lows and conditions" do
    today = @attributes[:today_forecast]
    assert_equal "2026-07-18", today["date"]
    assert_equal 25, today["high"]
    assert_equal 14, today["low"]
    assert_equal "Overcast", today["condition_label"]

    tomorrow = @attributes[:tomorrow_forecast]
    assert_equal 26, tomorrow["high"]
    assert_equal "Slight rain", tomorrow["condition_label"]
  end

  test "buckets hourly data into four 6-hour windows per day" do
    windows = @attributes[:hourly_windows]
    assert_equal 8, windows.size

    overnight = windows.find { |w| w["day"] == "today" && w["window"] == "overnight" }
    assert_equal 0, overnight["condition_code"]
    assert_equal "Clear sky", overnight["condition_label"]
    assert_kind_of Integer, overnight["temperature"]

    # Windows take the most severe (max) code in the range.
    afternoon = windows.find { |w| w["day"] == "today" && w["window"] == "afternoon" }
    assert_equal 61, afternoon["condition_code"]
  end

  test "maps a five day forecast" do
    forecast = @attributes[:five_day_forecast]
    assert_equal 5, forecast.size
    assert_equal 25, forecast.first["high"]
    assert_equal "2026-07-22", forecast.last["date"]
  end

  test "tolerates a missing or empty payload" do
    attributes = OpenMeteo::WeatherMapper.new(nil).attributes
    assert_nil attributes[:current_temperature]
    assert_equal({}, attributes[:today_forecast])
    assert_equal [], attributes[:hourly_windows]
    assert_equal [], attributes[:five_day_forecast]
  end
end
