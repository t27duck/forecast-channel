require "test_helper"

class MapsHelperTest < ActionView::TestCase
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

  private

  def with_mapbox_token(value)
    original = ENV["MAPBOX_TOKEN"]
    ENV["MAPBOX_TOKEN"] = value
    yield
  ensure
    ENV["MAPBOX_TOKEN"] = original
  end
end
