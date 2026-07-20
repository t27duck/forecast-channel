require "test_helper"

class RefreshWeatherBatchJobTest < ActiveJob::TestCase
  test "refreshes every location in the batch with one request" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }

    stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { payloads }) do
      RefreshWeatherBatchJob.perform_now(locations.map(&:id))
    end

    locations.each { |location| assert_not_nil location.reload.weather_refreshed_at }
  end

  test "ignores ids whose location has since been deleted" do
    missing_id = Location.maximum(:id) + 1

    stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { [] }) do
      assert_nothing_raised { RefreshWeatherBatchJob.perform_now([ missing_id ]) }
    end
  end
end
