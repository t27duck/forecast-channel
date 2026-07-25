require "test_helper"

class ForecastsHelperTest < ActionView::TestCase
  # In views current_setting is a controller helper reading cookies; supply a
  # stand-in here so the formatting helpers can be exercised directly.
  attr_writer :current_setting

  def current_setting
    @current_setting ||= Setting.new
  end

  test "panel_track_style scrolls the track to the panel, one track height per step" do
    assert_equal "transform: translateY(-0%)", panel_track_style("laundry")
    assert_equal "transform: translateY(-300%)", panel_track_style("current")
    assert_equal "transform: translateY(-600%)", panel_track_style("five_day")
  end

  test "panel_neighbour_title stops at the ends instead of looping" do
    assert_equal "UV Index", panel_neighbour_title("current", -1)
    assert_equal "Today", panel_neighbour_title("current", 1)
    assert_nil panel_neighbour_title("laundry", -1)
    assert_nil panel_neighbour_title("five_day", 1)
  end

  test "every panel in the list has a title and a partial, and the default is one of them" do
    ForecastsHelper::PANELS.each do |panel|
      assert_not_nil panel_title(panel[:key])
      assert File.exist?(Rails.root.join("app/views/locations/panels/_#{panel[:key]}.html.erb")),
        "no partial for the #{panel[:key]} panel"
    end
    assert_includes ForecastsHelper::PANELS.pluck(:key), ForecastsHelper::DEFAULT_PANEL
  end

  test "forecast_temperature formats with and without a degree sign" do
    assert_equal "18°", forecast_temperature(18.0)
    assert_equal "18", forecast_temperature(18.0, degree: false)
    assert_equal "--", forecast_temperature(nil)
  end

  test "forecast_temperature converts to the chosen unit" do
    self.current_setting = Setting.new(temperature_unit: "fahrenheit")
    assert_equal "64°", forecast_temperature(18.0) # 18C -> 64F
  end

  test "compass_direction maps bearings to 16-point labels" do
    assert_equal "N", compass_direction(0)
    assert_equal "SSE", compass_direction(160)
    assert_equal "W", compass_direction(270)
    assert_nil compass_direction(nil)
  end

  test "wind_display combines direction and speed in the chosen unit" do
    assert_equal "SSE 16 mph", wind_display(26, 160) # 26 km/h ~ 16 mph
    assert_nil wind_display(nil, 160)

    self.current_setting = Setting.new(wind_unit: "kph")
    assert_equal "SSE 26 kph", wind_display(26, 160)
  end

  test "forecast_time formats the local clock from an Open-Meteo timestamp" do
    assert_equal "5:12 a.m.", forecast_time("2026-07-18T05:12")
    assert_equal "9:30 p.m.", forecast_time("2026-07-18T21:30")
    assert_nil forecast_time(nil)
    assert_nil forecast_time("not-a-time")
  end

  test "apparent_range formats the feels-like high and low" do
    assert_equal "27° / 13°", apparent_range("apparent_high" => 27, "apparent_low" => 13)
    assert_nil apparent_range("apparent_high" => nil, "apparent_low" => nil)
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

  test "weekday_name returns the full uppercase weekday" do
    assert_equal "THURSDAY", weekday_name("2026-07-16")
    assert_nil weekday_name(nil)
  end

  test "weekend? is true only on Saturday and Sunday" do
    assert weekend?("2026-07-18"), "Saturday"
    assert weekend?("2026-07-19"), "Sunday"
    assert_not weekend?("2026-07-20"), "Monday"
    assert_not weekend?(nil)
    assert_not weekend?("nope")
  end

  test "six_hour_windows returns four ordered windows with data looked up by key" do
    location = Location.new(hourly_windows: [
      { "day" => "today", "window" => "morning", "condition_code" => 2 },
      { "day" => "tomorrow", "window" => "evening", "condition_code" => 3 }
    ])

    windows = six_hour_windows(location, "today")
    assert_equal %w[overnight morning afternoon evening], windows.map { |w| w[:key] }
    assert_equal "12:00 a.m.", windows.first[:from]
    assert_nil windows.first[:data] # overnight has no stored data
    assert_equal 2, windows.find { |w| w[:key] == "morning" }[:data]["condition_code"]
  end
end
