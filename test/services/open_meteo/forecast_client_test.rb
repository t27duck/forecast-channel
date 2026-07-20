require "test_helper"

class OpenMeteo::ForecastClientTest < ActiveSupport::TestCase
  test "returns the parsed payload on success" do
    body = { "current" => { "temperature_2m" => 12.3 } }.to_json
    response = ok_response(body)

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      payload = OpenMeteo::ForecastClient.fetch(latitude: 52.5, longitude: 13.4)
      assert_in_delta 12.3, payload.dig("current", "temperature_2m")
    end
  end

  test "returns nil on network failure" do
    stub_singleton(Net::HTTP, :start, ->(*, **) { raise SocketError, "no dns" }) do
      assert_nil OpenMeteo::ForecastClient.fetch(latitude: 52.5, longitude: 13.4)
    end
  end

  test "fetch_many returns one payload per coordinate, in order" do
    body = [
      { "timezone" => "Europe/Berlin" }, { "timezone" => "Asia/Tokyo" }
    ].to_json
    response = ok_response(body)

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      payloads = OpenMeteo::ForecastClient.fetch_many([ [ 52.5, 13.4 ], [ 35.7, 139.7 ] ])
      assert_equal %w[Europe/Berlin Asia/Tokyo], payloads.map { |p| p["timezone"] }
    end
  end

  test "fetch_many returns nil when the response doesn't match the request" do
    response = ok_response([ { "timezone" => "Europe/Berlin" } ].to_json) # one short

    stub_singleton(Net::HTTP, :start, ->(*, **, &_blk) { response }) do
      assert_nil OpenMeteo::ForecastClient.fetch_many([ [ 52.5, 13.4 ], [ 35.7, 139.7 ] ])
    end
  end

  test "fetch_many returns nil on network failure" do
    stub_singleton(Net::HTTP, :start, ->(*, **) { raise SocketError, "no dns" }) do
      assert_nil OpenMeteo::ForecastClient.fetch_many([ [ 52.5, 13.4 ] ])
    end
  end

  test "fetch_many skips the request entirely when there are no coordinates" do
    assert_equal [], OpenMeteo::ForecastClient.fetch_many([])
  end

  private

  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@stub_body, body)
    def response.body = @stub_body
    response
  end
end
