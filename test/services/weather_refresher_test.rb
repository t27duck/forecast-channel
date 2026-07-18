require "test_helper"

class WeatherRefresherTest < ActiveSupport::TestCase
  setup { @location = locations(:tokyo) }

  test "writes fetched weather onto the location" do
    payload = open_meteo_forecast_payload
    stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
      assert WeatherRefresher.call(@location)
    end

    @location.reload
    assert_in_delta 21.4, @location.current_temperature
    assert_equal "Overcast", @location.current_condition_label
    assert_equal "Moderate", @location.uv_label
    assert_equal 8, @location.hourly_windows.size
    assert_not_nil @location.weather_refreshed_at
    assert_not @location.weather_stale?
  end

  test "leaves the location untouched when the fetch fails" do
    stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { nil }) do
      assert_no_changes -> { @location.reload.attributes } do
        assert_not WeatherRefresher.call(@location)
      end
    end
  end
end
