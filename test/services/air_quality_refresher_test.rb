require "test_helper"

class AirQualityRefresherTest < ActiveSupport::TestCase
  setup { @location = locations(:tokyo) }

  test "writes fetched air quality onto the location" do
    payload = open_meteo_air_quality_payload(us_aqi: 84, pm2_5: 21.7)
    stub_singleton(OpenMeteo::AirQualityClient, :fetch, ->(**) { payload }) do
      assert AirQualityRefresher.call(@location)
    end

    @location.reload
    assert_equal 84, @location.air_quality_index
    assert_equal "Moderate", @location.air_quality_label
    assert_in_delta 21.7, @location.air_quality_pm2_5
  end

  test "call_many refreshes every location in one batched request" do
    locations = Location.all.to_a
    payloads = Array.new(locations.size) { open_meteo_air_quality_payload }
    calls = 0

    stub_singleton(OpenMeteo::AirQualityClient, :fetch_many, ->(_coords) { calls += 1; payloads }) do
      assert_equal locations.size, AirQualityRefresher.call_many(locations)
    end

    assert_equal 1, calls, "should batch into a single request"
    locations.each { |location| assert_equal 42, location.reload.air_quality_index }
  end

  test "leaves the location untouched when the fetch fails" do
    stub_singleton(OpenMeteo::AirQualityClient, :fetch, ->(**) { nil }) do
      assert_no_changes -> { @location.reload.air_quality_index } do
        assert_not AirQualityRefresher.call(@location)
      end
    end
  end
end
