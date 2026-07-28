require "test_helper"

class RefreshWeatherBatchJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  test "refreshes every location in the batch with one request" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }

    stub_air_quality do
      stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { payloads }) do
        RefreshWeatherBatchJob.perform_now(locations.map(&:id))
      end
    end

    locations.each do |location|
      assert_not_nil location.reload.weather_refreshed_at
      assert_equal 42, location.air_quality_index # air quality refreshed in the same job
    end
  end

  test "ignores ids whose location has since been deleted" do
    missing_id = Location.maximum(:id) + 1

    stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { [] }) do
      assert_nothing_raised { RefreshWeatherBatchJob.perform_now([ missing_id ]) }
    end
  end

  # An open globe holds the markers it fetched when it opened, so a refresh has
  # to tell it there's something new to read.
  test "announces the refresh, carrying a version to re-fetch with" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }

    streams = capture_turbo_stream_broadcasts(Location::WEATHER_STREAM) do
      stub_air_quality do
        stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { payloads }) do
          RefreshWeatherBatchJob.perform_now(locations.map(&:id))
        end
      end
    end

    assert_equal 1, streams.count
    assert_equal "weather_refreshed", streams.sole["action"]
    assert_predicate streams.sole["version"].to_i, :positive?
  end

  # A chunk whose fetch failed leaves every record exactly as it was, so there
  # is no news — and sending it anyway would have every open globe re-fetch a
  # feed that hasn't changed.
  test "says nothing when the fetch failed" do
    assert_no_turbo_stream_broadcasts Location::WEATHER_STREAM do
      stub_air_quality do
        stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { nil }) do
          RefreshWeatherBatchJob.perform_now(Location.ids)
        end
      end
    end
  end
end
