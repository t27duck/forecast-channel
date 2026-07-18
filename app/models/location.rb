class Location < ApplicationRecord
  # How long cached weather stays fresh before it should be refreshed.
  WEATHER_TTL = 1.hour

  RADIANS_PER_DEGREE = Math::PI / 180
  EARTH_RADIUS_KM = 6371.0

  validates :name, presence: true
  validates :latitude, presence: true,
    numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
    numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :by_name, -> { order(:name) }

  # The stored location closest to the given coordinates, or nil when there are
  # none. Fine to compute in Ruby at our scale (tens/hundreds of locations).
  def self.nearest_to(latitude, longitude)
    return nil if latitude.blank? || longitude.blank?

    all.min_by { |location| location.distance_km(latitude, longitude) }
  end

  # [latitude, longitude] pair, handy for mapping and API calls.
  def coordinates
    [ latitude, longitude ]
  end

  # Great-circle distance in kilometres from this location to a coordinate.
  def distance_km(other_latitude, other_longitude)
    lat1 = latitude.to_f * RADIANS_PER_DEGREE
    lat2 = other_latitude.to_f * RADIANS_PER_DEGREE
    delta_lat = (other_latitude.to_f - latitude.to_f) * RADIANS_PER_DEGREE
    delta_lng = (other_longitude.to_f - longitude.to_f) * RADIANS_PER_DEGREE

    a = (Math.sin(delta_lat / 2)**2) +
      (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(delta_lng / 2)**2))
    EARTH_RADIUS_KM * 2 * Math.asin(Math.sqrt(a))
  end

  # A readable label combining the place with its region/country,
  # e.g. "Berlin, Germany" or "Portland, Oregon".
  def display_name
    [ name, admin1.presence || country.presence ].compact.join(", ")
  end

  # Label for the currently stored weather condition code.
  def current_condition_name
    current_condition_label.presence || WeatherCode.label_for(current_condition_code)
  end

  # True when weather has never been fetched or has aged past the TTL.
  def weather_stale?
    weather_refreshed_at.nil? || weather_refreshed_at < WEATHER_TTL.ago
  end

  # Fetch fresh weather from Open-Meteo and store it. Returns true on success.
  def refresh_weather!
    WeatherRefresher.call(self)
  end
end
