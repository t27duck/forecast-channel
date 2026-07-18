require "net/http"
require "json"

module OpenMeteo
  # Looks up places by name via Open-Meteo's free geocoding API and returns
  # lightweight result objects with the coordinates and location metadata we
  # store on a Location.
  #
  # No API key is required. The client is failure-tolerant by design: it never
  # raises into the controller, returning an empty array for blank queries and
  # on any network or parse error (which are logged).
  #
  # Docs: https://open-meteo.com/en/docs/geocoding-api
  class GeocodingClient
    ENDPOINT = "https://geocoding-api.open-meteo.com/v1/search".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    # A single geocoding match. Attribute names mirror Location's columns so a
    # result can populate the new-location form directly.
    Result = Struct.new(
      :open_meteo_id, :name, :latitude, :longitude,
      :country, :country_code, :admin1, :timezone, :elevation, :population,
      keyword_init: true
    ) do
      def display_name
        [ name, admin1.presence || country.presence ].compact.join(", ")
      end
    end

    # Open-Meteo returns no results for empty or single-character queries.
    def self.search(query, count: 10)
      new.search(query, count: count)
    end

    def search(query, count: 10)
      query = query.to_s.strip
      return [] if query.length < 2

      body = get(query, count)
      return [] if body.nil?

      Array(body["results"]).map { |result| build_result(result) }
    rescue JSON::ParserError => error
      Rails.logger.warn("[OpenMeteo::GeocodingClient] parse error: #{error.message}")
      []
    end

    private

    def get(query, count)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(
        name: query, count: count, language: "en", format: "json"
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[OpenMeteo::GeocodingClient] HTTP #{response.code} for #{query.inspect}")
        return nil
      end

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError => error
      Rails.logger.warn("[OpenMeteo::GeocodingClient] request failed: #{error.message}")
      nil
    end

    def build_result(attributes)
      Result.new(
        open_meteo_id: attributes["id"],
        name: attributes["name"],
        latitude: attributes["latitude"],
        longitude: attributes["longitude"],
        country: attributes["country"],
        country_code: attributes["country_code"],
        admin1: attributes["admin1"],
        timezone: attributes["timezone"],
        elevation: attributes["elevation"],
        population: attributes["population"]
      )
    end
  end
end
