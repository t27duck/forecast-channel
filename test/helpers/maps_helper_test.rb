require "test_helper"

class MapsHelperTest < ActionView::TestCase
  # globe_fog_value asks the calendar what today is. Views get every helper
  # mixed in; this test case only gets the one it's named after.
  include ApplicationHelper

  test "the suite runs with no token, so the globe renders offline" do
    # test_helper clears MAPBOX_TOKEN however the machine came by it.
    assert_nil ENV["MAPBOX_TOKEN"]
    assert_nil mapbox_token
  end

  test "a token is passed through" do
    with_mapbox_token("pk.test") do
      assert_equal "pk.test", mapbox_token
    end
  end

  test "a blank MAPBOX_TOKEN counts as no token" do
    # What the example env files ship, and what an unfilled env file leaves
    # behind.
    with_mapbox_token("") do
      assert_nil mapbox_token
    end
  end

  test "the globe's fog is left to the JavaScript on an ordinary day" do
    travel_to Date.new(2026, 6, 15) do
      assert_nil globe_fog_value
    end
  end

  test "Halloween tints the globe's atmosphere" do
    travel_to Date.new(2026, 10, 31) do
      fog = JSON.parse(globe_fog_value)

      assert_equal MapsHelper::HALLOWEEN_FOG, fog
      # setFog replaces rather than merges, so a partial object would silently
      # hand the rest back to Mapbox's defaults.
      assert_equal %w[color high-color space-color star-intensity horizon-blend].sort, fog.keys.sort
    end
  end

  private

  def with_mapbox_token(value)
    original = ENV["MAPBOX_TOKEN"]
    ENV["MAPBOX_TOKEN"] = value
    yield
  ensure
    ENV["MAPBOX_TOKEN"] = original
  end
end
