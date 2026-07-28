require "test_helper"

class RefreshLocationWeatherJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  test "refreshes the location's weather, air quality included" do
    location = locations(:tokyo)
    payload = open_meteo_forecast_payload

    stub_air_quality do
      stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
        RefreshLocationWeatherJob.perform_now(location)
      end
    end

    assert_not_nil location.reload.weather_refreshed_at
    assert_equal 42, location.air_quality_index
  end

  # Staleness gated the work when it ran inside the request; now the answer no
  # longer waits for it, two arrivals a moment apart can both enqueue.
  test "leaves fresh weather alone, reaching nothing on the network" do
    location = locations(:berlin) # refreshed 30 minutes ago
    before = location.weather_refreshed_at

    # No client stub: touching Open-Meteo here would raise rather than hang.
    RefreshLocationWeatherJob.perform_now(location)

    assert_equal before.to_i, location.reload.weather_refreshed_at.to_i
  end

  test "tells the waiting splash when it's done" do
    location = locations(:tokyo)
    payload = open_meteo_forecast_payload

    streams = capture_turbo_stream_broadcasts(location.weather_stream) do
      stub_air_quality do
        stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
          RefreshLocationWeatherJob.perform_now(location)
        end
      end
    end

    assert_equal 1, streams.count
    assert_equal "weather_ready", streams.sole["action"]
    assert_equal location.slug, streams.sole["slug"]
  end

  # Whether Open-Meteo had anything new isn't the splash's business — it's
  # waiting to stop waiting, and a failed fetch shows the weather already
  # stored, which is what it would have shown anyway.
  test "answers even when there was nothing to do" do
    location = locations(:berlin) # already fresh

    assert_turbo_stream_broadcasts location.weather_stream, count: 1 do
      RefreshLocationWeatherJob.perform_now(location)
    end
  end
end
