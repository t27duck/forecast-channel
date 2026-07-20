require "test_helper"

class OpenMeteo::AirQualityClientTest < ActiveSupport::TestCase
  test "returns the parsed payload on success" do
    body = { "current" => { "us_aqi" => 42, "pm2_5" => 9.3 } }.to_json
    response = ok_response(body)

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      payload = OpenMeteo::AirQualityClient.fetch(latitude: 52.5, longitude: 13.4)
      assert_equal 42, payload.dig("current", "us_aqi")
    end
  end

  test "returns nil on network failure" do
    stub_singleton(Net::HTTP, :start, ->(*, **) { raise SocketError, "no dns" }) do
      assert_nil OpenMeteo::AirQualityClient.fetch(latitude: 52.5, longitude: 13.4)
    end
  end

  test "fetch_many returns one payload per coordinate, in order" do
    body = [ { "current" => { "us_aqi" => 10 } }, { "current" => { "us_aqi" => 90 } } ].to_json
    response = ok_response(body)

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      payloads = OpenMeteo::AirQualityClient.fetch_many([ [ 52.5, 13.4 ], [ 35.7, 139.7 ] ])
      assert_equal [ 10, 90 ], payloads.map { |p| p.dig("current", "us_aqi") }
    end
  end

  test "fetch_many returns nil when the response length doesn't match the request" do
    response = ok_response([ { "current" => { "us_aqi" => 10 } } ].to_json) # one short

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      assert_nil OpenMeteo::AirQualityClient.fetch_many([ [ 52.5, 13.4 ], [ 35.7, 139.7 ] ])
    end
  end

  test "fetch_many skips the request entirely when there are no coordinates" do
    assert_equal [], OpenMeteo::AirQualityClient.fetch_many([])
  end

  private

  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@stub_body, body)
    def response.body = @stub_body
    response
  end
end
