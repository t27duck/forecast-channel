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

  # The peeking sun's 12 o'clock ray ends exactly on y=0 where the sun is
  # placed, so its round cap — half of stroke-width 3 — was shaved flat by the
  # top of the viewBox until the composition was nudged inwards.
  test "the partly-cloudy sun keeps its ray caps inside the viewBox" do
    svg = weather_icon(GROUP_SAMPLES["partly"])
    inset = svg.match(/<g transform="translate\(([\d.]+) ([\d.]+)\)">/)
    assert_not_nil inset, "expected the sun and cloud to be inset from the corner"

    assert_operator inset.captures.last.to_f, :>=, 1.5,
      "the 12 o'clock ray's cap needs half a stroke width of clearance"
  end
end
