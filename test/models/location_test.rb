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
end
