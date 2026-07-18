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

  private

  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@stub_body, body)
    def response.body = @stub_body
    response
  end
end
