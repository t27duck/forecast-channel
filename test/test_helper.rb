ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

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
          "temperature_2m" => 21.4, "weather_code" => 3, "uv_index" => 5.2,
          "wind_speed_10m" => 18.3, "wind_direction_10m" => 160
        },
        "hourly" => { "time" => times, "temperature_2m" => temps, "weather_code" => codes },
        "daily" => {
          "time" => [ today, tomorrow, "2026-07-20", "2026-07-21", "2026-07-22" ],
          "temperature_2m_max" => [ 25.0, 26.0, 24.0, 23.0, 22.0 ],
          "temperature_2m_min" => [ 14.0, 15.0, 13.0, 12.0, 11.0 ],
          "weather_code" => [ 3, 61, 2, 0, 80 ],
          "uv_index_max" => [ 6.0, 7.0, 5.0, 4.0, 8.0 ],
          "wind_speed_10m_max" => [ 24.0, 20.5, 15.0, 12.0, 30.0 ],
          "wind_direction_10m_dominant" => [ 135, 200, 90, 270, 315 ]
        }
      }
    end
  end
end
