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

  # "Refresh all" fans out into a chunk per BATCH_SIZE and leaves only an
  # optimistic flash behind, so the management index watches its rows land.
  test "asks the open management index to re-render" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }

    streams = capture_turbo_stream_broadcasts(Location::INDEX_STREAM) do
      stub_air_quality do
        stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { payloads }) do
          RefreshWeatherBatchJob.perform_now(locations.map(&:id))
        end
      end
    end

    assert_equal 1, streams.count
    # A page refresh, not markup: the index renders temperatures in whichever
    # unit the admin reading it chose, which a broadcast can't know.
    assert_equal "refresh", streams.sole["action"]
  end

  # A chunk whose fetch failed leaves every record exactly as it was, so there
  # is no news — and sending it anyway would have every open globe re-fetch a
  # feed that hasn't changed.
  test "says nothing when the fetch failed" do
    stub_fetch = ->(_coords) { nil }

    assert_no_turbo_stream_broadcasts Location::WEATHER_STREAM do
      assert_no_turbo_stream_broadcasts Location::INDEX_STREAM do
        stub_air_quality do
          stub_singleton(OpenMeteo::ForecastClient, :fetch_many, stub_fetch) do
            RefreshWeatherBatchJob.perform_now(Location.ids)
          end
        end
      end
    end
  end

  # The globe subscribes to WEATHER_STREAM and a Turbo page refresh there would
  # tear down and rebuild the whole Mapbox instance, so the two must stay apart.
  test "the index's page refresh never reaches the globe's stream" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_forecast_payload }

    streams = capture_turbo_stream_broadcasts(Location::WEATHER_STREAM) do
      stub_air_quality do
        stub_singleton(OpenMeteo::ForecastClient, :fetch_many, ->(_coords) { payloads }) do
          RefreshWeatherBatchJob.perform_now(locations.map(&:id))
        end
      end
    end

    assert_equal [ "weather_refreshed" ], streams.map { |s| s["action"] }
  end
end
