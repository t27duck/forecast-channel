class Location < ApplicationRecord
  # How long cached weather stays fresh before it should be refreshed.
  WEATHER_TTL = 1.hour

  # The "hot" tier — refreshed hourly, while the rest refresh every few hours.
  # It's the big cities plus anywhere someone has actually looked at recently.
  HOT_CITY_COUNT = 50
  RECENTLY_VIEWED_WITHIN = 7.days

  # Don't rewrite last_viewed_at on every panel navigation.
  VIEW_TRACKING_INTERVAL = 10.minutes

  RADIANS_PER_DEGREE = Math::PI / 180
  EARTH_RADIUS_KM = 6371.0

  before_validation :assign_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :latitude, presence: true,
    numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
    numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  scope :by_name, -> { order(:name) }
  scope :most_populous, -> { where.not(population: nil).order(population: :desc).limit(HOT_CITY_COUNT) }
  scope :recently_viewed, -> { where(last_viewed_at: RECENTLY_VIEWED_WITHIN.ago..) }
  scope :hot, -> { where(id: hot_ids) }
  scope :cold, -> { where.not(id: hot_ids) }

  # Ids of the frequently-refreshed tier. Resolved in Ruby so the two halves stay
  # readable (and it's a trivial query at our scale).
  def self.hot_ids
    most_populous.ids | recently_viewed.ids
  end

  # The stored location closest to the given coordinates, or nil when there are
  # none. Fine to compute in Ruby at our scale (tens/hundreds of locations).
  def self.nearest_to(latitude, longitude)
    return nil if latitude.blank? || longitude.blank?

    all.min_by { |location| location.distance_km(latitude, longitude) }
  end

  # Locations are addressed by slug, not by id: ids shift whenever the database
  # is reseeded (db/seeds.rb upserts by open_meteo_id), and "berlin-berlin-
  # germany" says what it points at.
  def to_param
    slug
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

  # Fetch fresh weather (and air quality) from Open-Meteo and store it. The
  # result tracks the weather fetch; air quality is best-effort and never fails
  # the refresh. Returns true on success.
  def refresh_weather!
    refreshed = WeatherRefresher.call(self)
    AirQualityRefresher.call(self) if refreshed
    refreshed
  end

  # Category label for the stored air quality index.
  def air_quality_name
    air_quality_label.presence || AirQuality.label_for(air_quality_index)
  end

  # How well laundry will dry in the current conditions, or nil when the data
  # needed to judge (temperature/humidity) is missing.
  def laundry_rating
    LaundryIndex.rating(
      temperature: current_temperature,
      humidity: current_humidity,
      wind_speed: current_wind_speed,
      precipitation_probability: current_precipitation_probability
    )
  end

  # Records that someone looked at this location, which keeps it in the hot
  # refresh tier. Throttled, and written without touching updated_at.
  def mark_viewed!
    return if last_viewed_at.present? && last_viewed_at > VIEW_TRACKING_INTERVAL.ago

    update_column(:last_viewed_at, Time.current)
  end

  private

  # Keeps the slug in step with the name/region/country it's built from, so a
  # renamed location gets a URL that matches what the page says. Saves that
  # don't touch those parts (a weather refresh) leave it alone — including the
  # numeric suffix a collision may have added, which is why the guard accepts
  # "berlin-berlin-germany-2" as still current. (A place whose name ends in a
  # number makes that guard ambiguous; nowhere near worth handling.)
  def assign_slug
    base = slug_base
    return if base.blank? || slug.to_s.match?(/\A#{Regexp.escape(base)}(-\d+)?\z/)

    self.slug = available_slug(base)
  end

  def slug_base
    [ name, admin1, country ].map { |part| part&.parameterize }.compact_blank.join("-")
  end

  # The base itself, or base-2 / base-3 / … when another location holds it —
  # two same-named towns in one region would otherwise be unsaveable.
  def available_slug(base)
    return base unless slug_taken?(base)

    2.step { |suffix| return "#{base}-#{suffix}" unless slug_taken?("#{base}-#{suffix}") }
  end

  def slug_taken?(candidate)
    scope = self.class.where(slug: candidate)
    scope = scope.where.not(id: id) if persisted?
    scope.exists?
  end
end
