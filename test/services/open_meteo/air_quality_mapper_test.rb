require "test_helper"

class OpenMeteo::AirQualityMapperTest < ActiveSupport::TestCase
  test "maps the AQI, its label and PM2.5" do
    attributes = OpenMeteo::AirQualityMapper.new(open_meteo_air_quality_payload(us_aqi: 84, pm2_5: 21.7)).attributes
    assert_equal 84, attributes[:air_quality_index]
    assert_equal "Moderate", attributes[:air_quality_label]
    assert_in_delta 21.7, attributes[:air_quality_pm2_5]
  end

  test "tolerates a missing or empty payload" do
    attributes = OpenMeteo::AirQualityMapper.new(nil).attributes
    assert_nil attributes[:air_quality_index]
    assert_equal "Unknown", attributes[:air_quality_label]
    assert_nil attributes[:air_quality_pm2_5]
  end
end
