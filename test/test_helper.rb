ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Run the whole suite with no Mapbox token, whatever the machine had — a
# .env.test.local, or a shell that sourced the deploy values. The globe
# controller then takes its offline style: no style, tile or glyph request
# leaves the browser, so the suite depends on neither a token nor the network
# and a developer's machine tests exactly what CI (which has no token) tests.
#
# After the environment, so this wins over anything dotenv loaded. dotenv's
# autorestore snapshots ENV per test *after* this point, so a test that sets the
# token and doesn't clean up is still restored to blank.
ENV["MAPBOX_TOKEN"] = nil

require "rails/test_help"
# Not required by the gem's railtie, so the broadcast assertions have to be
# asked for by name before a test case can include them.
require "turbo/broadcastable/test_helper"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/cookie_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily replace a class/singleton method with +replacement+ for the
    # duration of the block, restoring the original afterwards. Minitest 6
    # dropped the built-in +stub+, so we provide a minimal equivalent.
    def stub_singleton(klass, name, replacement)
      singleton = klass.singleton_class
      original = singleton.instance_method(name)
      singleton.define_method(name, &replacement)
      yield
    ensure
      singleton.define_method(name, original)
    end

    # A representative Open-Meteo forecast payload (2 days of hourly data plus
    # 5 daily entries) for exercising the weather mapper and refresher.
    def open_meteo_forecast_payload(today: "2026-07-18", tomorrow: "2026-07-19")
      times, temps, codes = [], [], []
      [ today, tomorrow ].each do |date|
        (0..23).each do |hour|
          times << format("%sT%02d:00", date, hour)
          temps << (10 + hour).to_f
          codes << (hour < 6 ? 0 : hour < 12 ? 2 : hour < 18 ? 61 : 3)
        end
      end

      {
        "current" => {
          "temperature_2m" => 21.4, "apparent_temperature" => 19.8,
          "relative_humidity_2m" => 68, "weather_code" => 3,
          "uv_index" => 5.2, "wind_speed_10m" => 18.3, "wind_direction_10m" => 160,
          "precipitation_probability" => 20
        },
        "hourly" => { "time" => times, "temperature_2m" => temps, "weather_code" => codes },
        "daily" => {
          "time" => [ today, tomorrow, "2026-07-20", "2026-07-21", "2026-07-22" ],
          "temperature_2m_max" => [ 25.0, 26.0, 24.0, 23.0, 22.0 ],
          "temperature_2m_min" => [ 14.0, 15.0, 13.0, 12.0, 11.0 ],
          "apparent_temperature_max" => [ 27.0, 28.0, 25.0, 24.0, 23.0 ],
          "apparent_temperature_min" => [ 13.0, 14.0, 12.0, 11.0, 10.0 ],
          "weather_code" => [ 3, 61, 2, 0, 80 ],
          "uv_index_max" => [ 6.0, 7.0, 5.0, 4.0, 8.0 ],
          "wind_speed_10m_max" => [ 24.0, 20.5, 15.0, 12.0, 30.0 ],
          "wind_direction_10m_dominant" => [ 135, 200, 90, 270, 315 ],
          "sunrise" => [ "#{today}T05:12", "#{tomorrow}T05:13", "2026-07-20T05:14", "2026-07-21T05:15", "2026-07-22T05:16" ],
          "sunset" => [ "#{today}T21:30", "#{tomorrow}T21:29", "2026-07-20T21:28", "2026-07-21T21:27", "2026-07-22T21:26" ]
        }
      }
    end

    # A representative Open-Meteo air-quality payload for one location.
    def open_meteo_air_quality_payload(us_aqi: 42, pm2_5: 9.3)
      { "current" => { "us_aqi" => us_aqi, "pm2_5" => pm2_5 } }
    end

    # Stub the air-quality client (both single and batched) for the block, so
    # tests exercising a refresh don't reach the network for air quality.
    def stub_air_quality(payload = open_meteo_air_quality_payload)
      stub_singleton(OpenMeteo::AirQualityClient, :fetch, ->(**) { payload }) do
        stub_singleton(OpenMeteo::AirQualityClient, :fetch_many, ->(coords) { Array.new(coords.size) { payload } }) do
          yield
        end
      end
    end
  end
end
