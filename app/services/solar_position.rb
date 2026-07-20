# Tells whether the sun is above the horizon at a coordinate and time, so the
# globe can show day vs. night marker icons for each city's *current* weather.
#
# Uses a low-precision solar position (good to a fraction of a degree), which is
# far more than enough to decide day or night. Everything is derived from the
# absolute instant and the coordinate — no timezone lookup needed.
module SolarPosition
  RAD = Math::PI / 180
  # Julian date of the J2000.0 epoch and of the Unix epoch.
  J2000 = 2_451_545.0
  UNIX_EPOCH_JD = 2_440_587.5

  # Is the sun up at (latitude, longitude) at +at+? Coordinates in degrees.
  # Missing coordinates default to daytime (the neutral, sunlit icon).
  def self.day?(latitude:, longitude:, at: Time.current)
    return true if latitude.nil? || longitude.nil?

    sun = subsolar_point(at)
    # Cosine of the solar zenith angle; positive means the sun is above the
    # horizon (spherical law of cosines for the sun-to-point angle).
    cos_zenith =
      Math.sin(sun[:lat] * RAD) * Math.sin(latitude * RAD) +
      Math.cos(sun[:lat] * RAD) * Math.cos(latitude * RAD) *
        Math.cos((longitude - sun[:lng]) * RAD)

    cos_zenith.positive?
  end

  # The point on Earth where the sun is directly overhead, in degrees.
  def self.subsolar_point(time)
    n = time.to_f / 86_400 + UNIX_EPOCH_JD - J2000 # days since J2000.0 (UTC)

    mean_longitude = (280.46 + 0.9856474 * n) % 360
    mean_anomaly = (357.528 + 0.9856003 * n) % 360
    ecliptic_longitude = mean_longitude +
      1.915 * Math.sin(mean_anomaly * RAD) +
      0.020 * Math.sin(2 * mean_anomaly * RAD)
    obliquity = 23.439 - 0.0000004 * n

    declination = Math.asin(Math.sin(obliquity * RAD) * Math.sin(ecliptic_longitude * RAD)) / RAD
    right_ascension = Math.atan2(
      Math.cos(obliquity * RAD) * Math.sin(ecliptic_longitude * RAD),
      Math.cos(ecliptic_longitude * RAD)
    ) / RAD
    sidereal_time = (280.46061837 + 360.98564736629 * n) % 360

    { lat: declination, lng: wrap180(right_ascension - sidereal_time) }
  end
  private_class_method :subsolar_point

  # Normalize degrees to the [-180, 180) range.
  def self.wrap180(degrees)
    (degrees + 180) % 360 - 180
  end
  private_class_method :wrap180
end
