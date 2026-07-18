require "test_helper"

class RefreshLocationWeatherJobTest < ActiveJob::TestCase
  test "refreshes the location's weather" do
    location = locations(:tokyo)
    payload = open_meteo_forecast_payload

    stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
      RefreshLocationWeatherJob.perform_now(location)
    end

    assert_not_nil location.reload.weather_refreshed_at
  end
end
