module OpenMeteo
  # Fetches current air quality for a coordinate from Open-Meteo's Air Quality
  # API — a separate endpoint from the weather forecast, but with the same
  # batching contract (comma-separated coordinates -> array of payloads in the
  # same order). Returns the raw parsed payload, or nil on any failure.
  #
  # Docs: https://open-meteo.com/en/docs/air-quality-api
  class AirQualityClient
    ENDPOINT = "https://air-quality-api.open-meteo.com/v1/air-quality".freeze
    CURRENT_VARIABLES = %w[us_aqi pm2_5].freeze

    # A batch response carries far more data than a single location's.
    BATCH_READ_TIMEOUT = 20

    def self.fetch(latitude:, longitude:)
      new.fetch(latitude: latitude, longitude: longitude)
    end

    def self.fetch_many(coordinates)
      new.fetch_many(coordinates)
    end

    def fetch(latitude:, longitude:)
      Request.get_json(ENDPOINT, query(latitude, longitude))
    end

    # Takes [[lat, lng], ...] and returns [payload, ...] in the same order, or
    # nil on failure. Like the forecast API, the response has no per-location
    # key, so a length mismatch fails the whole batch closed rather than risk
    # mispairing air-quality data with the wrong city.
    def fetch_many(coordinates)
      return [] if coordinates.empty?

      payloads = Request.get_json(ENDPOINT,
        query(coordinates.map(&:first).join(","), coordinates.map(&:last).join(",")),
        read_timeout: BATCH_READ_TIMEOUT)

      return payloads if payloads.is_a?(Array) && payloads.size == coordinates.size

      Rails.logger.warn("[OpenMeteo] air-quality batch of #{coordinates.size} returned an unusable response")
      nil
    end

    private

    def query(latitude, longitude)
      {
        latitude: latitude,
        longitude: longitude,
        current: CURRENT_VARIABLES.join(",")
      }
    end
  end
end
