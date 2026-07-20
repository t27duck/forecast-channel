require "test_helper"

class AirQualityTest < ActiveSupport::TestCase
  test "label_for maps US AQI to EPA categories" do
    assert_equal "Good", AirQuality.label_for(0)
    assert_equal "Good", AirQuality.label_for(50)
    assert_equal "Moderate", AirQuality.label_for(75)
    assert_equal "Unhealthy for sensitive groups", AirQuality.label_for(120)
    assert_equal "Unhealthy", AirQuality.label_for(175)
    assert_equal "Very unhealthy", AirQuality.label_for(250)
    assert_equal "Hazardous", AirQuality.label_for(400)
    assert_equal "Unknown", AirQuality.label_for(nil)
  end

  test "key_for returns a colour key per band" do
    assert_equal "good", AirQuality.key_for(30)
    assert_equal "moderate", AirQuality.key_for(80)
    assert_equal "sensitive", AirQuality.key_for(130)
    assert_equal "very-unhealthy", AirQuality.key_for(275)
    assert_equal "hazardous", AirQuality.key_for(500)
    assert_equal "unknown", AirQuality.key_for(nil)
  end
end
