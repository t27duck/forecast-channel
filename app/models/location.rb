class Location < ApplicationRecord
  # How long cached weather stays fresh before it should be refreshed.
  WEATHER_TTL = 1.hour

  validates :name, presence: true
  validates :latitude, presence: true,
    numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
    numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :by_name, -> { order(:name) }

  # [latitude, longitude] pair, handy for mapping and API calls.
  def coordinates
    [ latitude, longitude ]
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
