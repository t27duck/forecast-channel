require "test_helper"

class SolarPositionTest < ActiveSupport::TestCase
  # At noon UTC the sun is near the Greenwich meridian.
  NOON_UTC = Time.utc(2026, 7, 20, 12, 0, 0)
  MIDNIGHT_UTC = Time.utc(2026, 7, 20, 0, 0, 0)

  test "day? is true where the sun is up and false where it is down" do
    assert SolarPosition.day?(latitude: 51.5, longitude: -0.13, at: NOON_UTC), "London at noon UTC"
    assert_not SolarPosition.day?(latitude: -18, longitude: 178, at: NOON_UTC), "Fiji at noon UTC"
  end

  test "day? flips with the earth's rotation" do
    assert_not SolarPosition.day?(latitude: 51.5, longitude: -0.13, at: MIDNIGHT_UTC), "London at midnight UTC"
    assert SolarPosition.day?(latitude: 35.7, longitude: 139.7, at: MIDNIGHT_UTC), "Tokyo at midnight UTC (morning local)"
  end

  test "day? defaults to daytime when coordinates are missing" do
    assert SolarPosition.day?(latitude: nil, longitude: nil, at: NOON_UTC)
  end

  test "the summer sun sits over the northern tropics" do
    # A month past the June solstice the subsolar latitude is ~+20.6°.
    point = SolarPosition.send(:subsolar_point, NOON_UTC)
    assert_in_delta 20.6, point[:lat], 0.5
  end
end
