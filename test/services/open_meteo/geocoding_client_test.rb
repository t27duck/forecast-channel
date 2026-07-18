require "test_helper"

class OpenMeteo::GeocodingClientTest < ActiveSupport::TestCase
  RESPONSE_BODY = {
    results: [
      {
        id: 2950159, name: "Berlin", latitude: 52.52437, longitude: 13.41053,
        elevation: 74.0, country: "Germany", country_code: "DE",
        admin1: "Berlin", timezone: "Europe/Berlin", population: 3426354
      }
    ]
  }.to_json

  test "blank or single-character queries return no results without a request" do
    assert_equal [], OpenMeteo::GeocodingClient.search("")
    assert_equal [], OpenMeteo::GeocodingClient.search(" ")
    assert_equal [], OpenMeteo::GeocodingClient.search("a")
  end

  test "parses a successful response into result structs" do
    stub_http(ok_response(RESPONSE_BODY)) do
      results = OpenMeteo::GeocodingClient.search("Berlin")

      assert_equal 1, results.size
      result = results.first
      assert_equal "Berlin", result.name
      assert_in_delta 52.52437, result.latitude
      assert_in_delta 13.41053, result.longitude
      assert_equal "Germany", result.country
      assert_equal "Europe/Berlin", result.timezone
      assert_equal 2950159, result.open_meteo_id
      assert_equal "Berlin, Berlin", result.display_name
    end
  end

  test "returns an empty array on network failure" do
    stub_http(->(*, **) { raise SocketError, "getaddrinfo failed" }) do
      assert_equal [], OpenMeteo::GeocodingClient.search("Berlin")
    end
  end

  test "returns an empty array on a non-success HTTP status" do
    stub_http(Net::HTTPServerError.new("1.1", "500", "Internal Server Error")) do
      assert_equal [], OpenMeteo::GeocodingClient.search("Berlin")
    end
  end

  private

  # Replaces Net::HTTP.start so no real request is made. A non-callable value
  # is returned directly; a callable is invoked with the connection args.
  def stub_http(value, &test)
    replacement = value.respond_to?(:call) ? value : ->(*, **, &_blk) { value }
    stub_singleton(Net::HTTP, :start, replacement, &test)
  end

  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@stub_body, body)
    def response.body = @stub_body
    response
  end
end
