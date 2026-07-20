require "test_helper"

class WeatherIconsHelperTest < ActionView::TestCase
  # A representative WMO code for each icon group.
  GROUP_SAMPLES = {
    "clear" => 0, "partly" => 2, "overcast" => 3, "fog" => 45,
    "drizzle" => 51, "sleet" => 66, "rain" => 63, "heavy_rain" => 65,
    "snow" => 73, "heavy_snow" => 75, "thunder" => 95, "hail" => 96
  }.freeze

  UNKNOWN_FILL = "94a3b8".freeze # the grey of the fallback mark

  test "renders a glossy icon for every weather group without falling back to unknown" do
    GROUP_SAMPLES.each do |group, code|
      svg = weather_icon(code)
      assert_includes svg, "<svg", "#{group} should render an svg"
      assert_includes svg, WeatherCode.label_for(code), "#{group} should label itself"
      assert_not_includes svg, UNKNOWN_FILL, "#{group} should not use the unknown fallback"
    end
  end

  test "an unrecognized code renders the fallback mark" do
    assert_includes weather_icon(1234), UNKNOWN_FILL
  end
end
