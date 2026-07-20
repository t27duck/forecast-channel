require "net/http"
require "json"

module OpenMeteo
  # Shared helper for the Open-Meteo HTTP APIs. Performs a GET, parses the JSON
  # body, and is failure-tolerant: it never raises, returning nil on a
  # non-success status or any network/parse error (all of which are logged).
  module Request
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    module_function

    # Returns the parsed JSON body (a Hash, or an Array for multi-location
    # requests), or nil on failure. Batch requests return much more data, so the
    # read timeout is adjustable.
    def get_json(endpoint, params, read_timeout: READ_TIMEOUT)
      uri = URI(endpoint)
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout) do |http|
        http.get(uri.request_uri)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[OpenMeteo] HTTP #{response.code} for #{endpoint}")
        return nil
      end

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError, JSON::ParserError => error
      Rails.logger.warn("[OpenMeteo] request to #{endpoint} failed: #{error.message}")
      nil
    end
  end
end
