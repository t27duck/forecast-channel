require "test_helper"

class ForecastsHelperTest < ActionView::TestCase
  test "forecast_temperature formats with and without a degree sign" do
    assert_equal "18°", forecast_temperature(18.0)
    assert_equal "18", forecast_temperature(18.0, degree: false)
    assert_equal "--", forecast_temperature(nil)
  end

  test "forecast_temperature converts to the chosen unit" do
    Setting.current.fahrenheit!
    assert_equal "64°", forecast_temperature(18.0) # 18C -> 64F
  end

  test "compass_direction maps bearings to 16-point labels" do
    assert_equal "N", compass_direction(0)
    assert_equal "SSE", compass_direction(160)
    assert_equal "W", compass_direction(270)
    assert_nil compass_direction(nil)
  end

  test "wind_display combines direction and mph" do
    assert_equal "SSE 16 mph", wind_display(26, 160) # 26 km/h ~ 16 mph
    assert_nil wind_display(nil, 160)
  end

  test "as_of formats the local time" do
    time = Time.utc(2026, 7, 18, 20, 0)
    assert_equal "As of 3:00 p.m., 07/18", as_of(time, "America/Chicago")
    assert_nil as_of(nil)
  end

  test "weekday_abbr returns an uppercase day" do
    assert_equal "SAT", weekday_abbr("2026-07-18")
    assert_nil weekday_abbr(nil)
  end
end
