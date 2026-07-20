require "test_helper"

class LaundryIndexTest < ActiveSupport::TestCase
  test "warm, dry, breezy and rain-free conditions rate excellent" do
    rating = LaundryIndex.rating(temperature: 26, humidity: 40, wind_speed: 15, precipitation_probability: 5)
    assert_equal "excellent", rating.key
    assert_equal "Excellent", rating.label
    assert rating.blurb.present?
  end

  test "likely rain drags the rating down to poor" do
    rating = LaundryIndex.rating(temperature: 24, humidity: 40, wind_speed: 15, precipitation_probability: 90)
    assert_equal "poor", rating.key
  end

  test "cold, muggy and still conditions rate poorly" do
    rating = LaundryIndex.rating(temperature: 3, humidity: 92, wind_speed: 1, precipitation_probability: 30)
    assert_equal "poor", rating.key
  end

  test "middling conditions land in the fair/good range" do
    rating = LaundryIndex.rating(temperature: 18, humidity: 60, wind_speed: 8, precipitation_probability: 20)
    assert_includes %w[good fair], rating.key
  end

  test "missing temperature or humidity yields no rating" do
    assert_nil LaundryIndex.rating(temperature: nil, humidity: 50, wind_speed: 10, precipitation_probability: 0)
    assert_nil LaundryIndex.rating(temperature: 20, humidity: nil, wind_speed: 10, precipitation_probability: 0)
  end

  test "missing wind and rain are treated neutrally, not as zero" do
    rating = LaundryIndex.rating(temperature: 20, humidity: 55, wind_speed: nil, precipitation_probability: nil)
    assert_not_nil rating
    # Warm-ish (+1) and comfortable humidity (+1) with neutral wind/rain -> good.
    assert_equal "good", rating.key
  end
end
