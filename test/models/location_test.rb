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

  test "slug is built from the name, region and country" do
    location = Location.create!(name: "São Paulo", admin1: "São Paulo", country: "Brazil",
      latitude: -23.5, longitude: -46.6)
    assert_equal "sao-paulo-sao-paulo-brazil", location.slug
    assert_equal location.slug, location.to_param
  end

  test "slug drops the parts a location doesn't have" do
    location = Location.create!(name: "Nowhere", latitude: 1, longitude: 2)
    assert_equal "nowhere", location.slug
  end

  test "a location whose slug is taken gets a numeric suffix" do
    parts = { name: "Manchester", admin1: "England", country: "United Kingdom" }
    first = Location.create!(**parts, latitude: 53.48, longitude: -2.24)
    second = Location.create!(**parts, latitude: 53.49, longitude: -2.25)
    third = Location.create!(**parts, latitude: 53.50, longitude: -2.26)

    assert_equal "manchester-england-united-kingdom", first.slug
    assert_equal "manchester-england-united-kingdom-2", second.slug
    assert_equal "manchester-england-united-kingdom-3", third.slug
  end

  test "renaming a location regenerates its slug" do
    location = Location.create!(name: "Bombay", country: "India", latitude: 19.07, longitude: 72.87)
    assert_equal "bombay-india", location.slug

    location.update!(name: "Mumbai")
    assert_equal "mumbai-india", location.slug
  end

  test "a save that doesn't touch the name leaves the slug alone" do
    location = locations(:berlin)
    slug = location.slug

    location.update!(current_temperature: 21.0)
    assert_equal slug, location.reload.slug
  end

  test "a suffixed slug survives a save that doesn't rename the location" do
    parts = { admin1: "England", country: "United Kingdom", latitude: 53.48, longitude: -2.24 }
    Location.create!(name: "Manchester", **parts)
    second = Location.create!(name: "Manchester", **parts)

    second.update!(current_temperature: 12.0)
    assert_equal "manchester-england-united-kingdom-2", second.reload.slug
  end

  test "display_name combines name and region" do
    assert_equal "Berlin, Berlin", locations(:berlin).display_name
  end

  test "current_condition_name falls back to the code label" do
    location = Location.new(current_condition_code: 61, current_condition_label: nil)
    assert_equal "Slight rain", location.current_condition_name
  end

  test "air_quality_name falls back to the label for the stored index" do
    assert_equal "Moderate", Location.new(air_quality_index: 80, air_quality_label: nil).air_quality_name
    assert_equal "Good", Location.new(air_quality_index: 20, air_quality_label: "Good").air_quality_name
  end

  test "laundry_rating derives a rating from the stored conditions" do
    location = Location.new(current_temperature: 26, current_humidity: 40,
      current_wind_speed: 15, current_precipitation_probability: 5)
    assert_equal "excellent", location.laundry_rating.key
  end

  test "laundry_rating is nil without the conditions it needs" do
    assert_nil Location.new(current_temperature: nil, current_humidity: nil).laundry_rating
  end

  test "refresh_weather! also refreshes air quality, but air quality never fails it" do
    location = locations(:tokyo)
    forecast = open_meteo_forecast_payload

    # Air quality unreachable (nil) must not flip the weather refresh to a failure.
    stub_singleton(OpenMeteo::AirQualityClient, :fetch, ->(**) { nil }) do
      stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { forecast }) do
        assert location.refresh_weather!
      end
    end
    assert_nil location.reload.air_quality_index

    stub_air_quality(open_meteo_air_quality_payload(us_aqi: 55)) do
      stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { forecast }) do
        assert location.refresh_weather!
      end
    end
    assert_equal 55, location.reload.air_quality_index
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

  test "most_populous takes the biggest cities, as many as it is asked for" do
    big = Location.create!(name: "Metropolis", latitude: 1, longitude: 1, population: 90_000_000)
    small = Location.create!(name: "Smallville", latitude: 2, longitude: 2, population: 100)

    assert_equal [ big ], Location.most_populous(1)
    assert_includes Location.most_populous, small # defaults to the whole hot tier
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
