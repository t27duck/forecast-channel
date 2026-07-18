module OpenMeteo
  # Fetches the current conditions and forecast for a coordinate from the
  # Open-Meteo forecast API. Returns the raw parsed payload (Hash) so a mapper
  # can shape it into Location attributes, or nil on any failure.
  #
  # Times come back in the location's local timezone (timezone=auto) so the
  # 6-hour windows bucket correctly.
  #
  # Docs: https://open-meteo.com/en/docs
  class ForecastClient
    ENDPOINT = "https://api.open-meteo.com/v1/forecast".freeze
    FORECAST_DAYS = 5
    TEMPERATURE_UNIT = "celsius".freeze

    CURRENT_VARIABLES = %w[temperature_2m weather_code uv_index].freeze
    HOURLY_VARIABLES = %w[temperature_2m weather_code].freeze
    DAILY_VARIABLES = %w[temperature_2m_max temperature_2m_min weather_code uv_index_max].freeze

    def self.fetch(latitude:, longitude:)
      new.fetch(latitude: latitude, longitude: longitude)
    end

    def fetch(latitude:, longitude:)
      Request.get_json(ENDPOINT,
        latitude: latitude,
        longitude: longitude,
        current: CURRENT_VARIABLES.join(","),
        hourly: HOURLY_VARIABLES.join(","),
        daily: DAILY_VARIABLES.join(","),
        timezone: "auto",
        forecast_days: FORECAST_DAYS,
        temperature_unit: TEMPERATURE_UNIT)
    end
  end
end
