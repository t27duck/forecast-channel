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

  test "call_many refreshes every location in one batched request" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }
    calls = 0

    stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { calls += 1; payloads }) do
      assert_equal locations.size, WeatherRefresher.call_many(locations)
    end

    assert_equal 1, calls, "should batch into a single request"
    locations.each { |location| assert_not location.reload.weather_stale? }
  end

  test "call_many leaves the batch untouched when the fetch fails" do
    locations = Location.all.to_a

    stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { nil }) do
      assert_no_changes -> { Location.order(:id).pluck(:weather_refreshed_at) } do
        assert_equal 0, WeatherRefresher.call_many(locations)
      end
    end
  end

  test "leaves the location untouched when the fetch fails" do
    stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { nil }) do
      assert_no_changes -> { @location.reload.attributes } do
        assert_not WeatherRefresher.call(@location)
      end
    end
  end
end
