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

    CURRENT_VARIABLES = %w[
      temperature_2m apparent_temperature relative_humidity_2m weather_code
      uv_index wind_speed_10m wind_direction_10m precipitation_probability
    ].freeze
    HOURLY_VARIABLES = %w[temperature_2m weather_code].freeze
    DAILY_VARIABLES = %w[
      temperature_2m_max temperature_2m_min apparent_temperature_max
      apparent_temperature_min weather_code uv_index_max
      wind_speed_10m_max wind_direction_10m_dominant sunrise sunset
    ].freeze

    # A batch response carries far more data than a single location's.
    BATCH_READ_TIMEOUT = 20

    def self.fetch(latitude:, longitude:)
      new.fetch(latitude: latitude, longitude: longitude)
    end

    # Fetches several coordinates in one request. Open-Meteo accepts
    # comma-separated coordinate lists and answers with an array of payloads in
    # the same order (timezone=auto still resolves per location).
    def self.fetch_many(coordinates)
      new.fetch_many(coordinates)
    end

    def fetch(latitude:, longitude:)
      Request.get_json(ENDPOINT, query(latitude, longitude))
    end

    # Takes [[lat, lng], ...] and returns [payload, ...] in the same order, or
    # nil on failure. The response has no reliable per-location key, so callers
    # zip positionally — an unexpected length means we can't trust the pairing
    # and the whole batch fails closed.
    def fetch_many(coordinates)
      return [] if coordinates.empty?

      payloads = Request.get_json(ENDPOINT,
        query(coordinates.map(&:first).join(","), coordinates.map(&:last).join(",")),
        read_timeout: BATCH_READ_TIMEOUT)

      return payloads if payloads.is_a?(Array) && payloads.size == coordinates.size

      Rails.logger.warn("[OpenMeteo] batch of #{coordinates.size} returned an unusable response")
      nil
    end

    private

    def query(latitude, longitude)
      {
        latitude: latitude,
        longitude: longitude,
        current: CURRENT_VARIABLES.join(","),
        hourly: HOURLY_VARIABLES.join(","),
        daily: DAILY_VARIABLES.join(","),
        timezone: "auto",
        forecast_days: FORECAST_DAYS,
        temperature_unit: TEMPERATURE_UNIT
      }
    end
  end
end
