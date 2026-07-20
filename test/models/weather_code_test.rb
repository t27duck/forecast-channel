require "test_helper"

class WeatherCodeTest < ActiveSupport::TestCase
  test "label_for maps codes and falls back to Unknown" do
    assert_equal "Clear sky", WeatherCode.label_for(0)
    assert_equal "Slight rain", WeatherCode.label_for(61)
    assert_equal "Unknown", WeatherCode.label_for(nil)
    assert_equal "Unknown", WeatherCode.label_for(1234)
  end

  test "icon_group buckets codes into icon names" do
    assert_equal "clear", WeatherCode.icon_group(1)
    assert_equal "partly", WeatherCode.icon_group(2)
    assert_equal "overcast", WeatherCode.icon_group(3)
    assert_equal "fog", WeatherCode.icon_group(48)
    assert_equal "rain", WeatherCode.icon_group(65)
    assert_equal "rain", WeatherCode.icon_group(81)
    assert_equal "snow", WeatherCode.icon_group(73)
    assert_equal "thunder", WeatherCode.icon_group(95)
    assert_equal "unknown", WeatherCode.icon_group(nil)
  end

  test "icon_group returns night variants for clear and partly at night" do
    assert_equal "clear_night", WeatherCode.icon_group(0, is_day: false)
    assert_equal "partly_night", WeatherCode.icon_group(2, is_day: false)
  end

  test "icon_group keeps cloudy and precip groups the same at night" do
    # An overcast/rainy/etc. sky hides the sun or moon, so there's no night art.
    assert_equal "overcast", WeatherCode.icon_group(3, is_day: false)
    assert_equal "rain", WeatherCode.icon_group(65, is_day: false)
    assert_equal "snow", WeatherCode.icon_group(73, is_day: false)
    assert_equal "unknown", WeatherCode.icon_group(nil, is_day: false)
  end
end
