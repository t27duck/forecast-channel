require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "valid with name and coordinates" do
    assert locations(:berlin).valid?
  end

  test "nearest_to returns the closest location" do
    # Warsaw is far closer to Berlin than to Tokyo.
    assert_equal locations(:berlin), Location.nearest_to(52.23, 21.01)
    # A point near Japan resolves to Tokyo.
    assert_equal locations(:tokyo), Location.nearest_to(34.69, 135.50)
  end

  test "nearest_to returns nil without coordinates or locations" do
    assert_nil Location.nearest_to(nil, nil)
    assert_nil Location.none.nearest_to(1, 2)
  end

  test "distance_km measures the great-circle distance" do
    # Berlin (52.52, 13.41) to Warsaw (52.23, 21.01) is ~520 km.
    assert_in_delta 520, locations(:berlin).distance_km(52.23, 21.01), 30
  end

  test "requires a name" do
    location = Location.new(latitude: 10, longitude: 20)
    assert_not location.valid?
    assert_includes location.errors[:name], "can't be blank"
  end

  test "requires latitude and longitude" do
    location = Location.new(name: "Nowhere")
    assert_not location.valid?
    assert_includes location.errors[:latitude], "can't be blank"
    assert_includes location.errors[:longitude], "can't be blank"
  end

  test "rejects out-of-range coordinates" do
    location = Location.new(name: "Off world", latitude: 120, longitude: 250)
    assert_not location.valid?
    assert_predicate location.errors[:latitude], :any?
    assert_predicate location.errors[:longitude], :any?
  end

  test "display_name combines name and region" do
    assert_equal "Berlin, Berlin", locations(:berlin).display_name
  end

  test "current_condition_name falls back to the code label" do
    location = Location.new(current_condition_code: 61, current_condition_label: nil)
    assert_equal "Slight rain", location.current_condition_name
  end

  test "weather_stale? is true when never refreshed and false when fresh" do
    assert_predicate locations(:tokyo), :weather_stale?
    assert_not locations(:berlin).weather_stale?
  end

  test "the hot tier holds the biggest cities plus anywhere recently viewed" do
    big = Location.create!(name: "Metropolis", latitude: 1, longitude: 1, population: 90_000_000)
    viewed = Location.create!(name: "Smallville", latitude: 2, longitude: 2,
      population: 100, last_viewed_at: 1.hour.ago)
    # No population at all, and not looked at in a long time.
    forgotten = Location.create!(name: "Hamlet", latitude: 3, longitude: 3,
      population: nil, last_viewed_at: 30.days.ago)

    assert_includes Location.hot, big
    assert_includes Location.hot, viewed
    assert_includes Location.cold, forgotten
    assert_not_includes Location.hot, forgotten
  end

  test "hot and cold partition every location" do
    assert_equal Location.count, Location.hot.count + Location.cold.count
  end

  test "mark_viewed! stamps the view, then throttles repeats" do
    location = locations(:tokyo)
    assert_nil location.last_viewed_at

    location.mark_viewed!
    first = location.reload.last_viewed_at
    assert_not_nil first

    location.mark_viewed! # within the throttle window, so unchanged
    assert_equal first, location.reload.last_viewed_at

    location.update_column(:last_viewed_at, 1.hour.ago)
    location.mark_viewed!
    assert_operator location.reload.last_viewed_at, :>, 1.minute.ago
  end
end
