# Serializes locations into a GeoJSON FeatureCollection for the globe's symbol
# layer. Each feature carries the icon group (chosen from the weather code) and
# population, which the layer uses as a collision priority so larger cities win
# when markers overlap.
class LocationGeojson
  # Every column feature/1 reads, and no more. Selecting these keeps the two
  # largest JSON columns — five_day_forecast and hourly_windows, which the globe
  # never shows — out of memory and, more to the point, unparsed: a `json`
  # column on SQLite is text that Active Record parses on first access, so
  # loading them costs real time once there are thousands of locations.
  # location_geojson_test.rb guards that this list stays complete.
  COLUMNS = %i[
    id slug name latitude longitude population
    current_temperature current_condition_code current_condition_label
    today_forecast tomorrow_forecast
  ].freeze

  def self.feature_collection(locations)
    {
      type: "FeatureCollection",
      features: locations.map { |location| feature(location) }
    }
  end

  def self.feature(location)
    code = location.current_condition_code
    # The current marker follows the location's local day/night; a day's
    # forecast (and the fallback when it's missing) always uses the day icon.
    day_icon = WeatherCode.icon_group(code)
    current_icon = WeatherCode.icon_group(code, is_day: daytime?(location))
    today = location.today_forecast
    tomorrow = location.tomorrow_forecast

    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [ location.longitude.to_f, location.latitude.to_f ]
      },
      properties: {
        slug: location.slug, # what the globe navigates to on a marker click
        name: location.name,
        # One icon per globe view (current / today / tomorrow); the layer swaps
        # which one it renders as the user cycles the "Next" button.
        icon: current_icon,
        icon_today: forecast_icon(today, day_icon),
        icon_tomorrow: forecast_icon(tomorrow, day_icon),
        population: location.population || 0,
        # Weather for the hover popup — temperatures in Celsius; the client
        # converts to the display unit. Keys match the globe's three views.
        temp: location.current_temperature&.round,
        label: location.current_condition_name,
        today_high: daily(today, "high"),
        today_low: daily(today, "low"),
        today_label: daily(today, "condition_label"),
        tomorrow_high: daily(tomorrow, "high"),
        tomorrow_low: daily(tomorrow, "low"),
        tomorrow_label: daily(tomorrow, "condition_label")
      }
    }
  end

  # Whether it's currently daytime at the location (drives the night icon).
  def self.daytime?(location)
    SolarPosition.day?(latitude: location.latitude, longitude: location.longitude)
  end
  private_class_method :daytime?

  # Icon group for a stored daily forecast, falling back to the current icon
  # when that day hasn't been fetched yet.
  def self.forecast_icon(forecast, fallback)
    code = forecast["condition_code"] if forecast.is_a?(Hash)
    code.nil? ? fallback : WeatherCode.icon_group(code)
  end
  private_class_method :forecast_icon

  # A value from a stored daily forecast hash, or nil when absent.
  def self.daily(forecast, key)
    forecast[key] if forecast.is_a?(Hash)
  end
  private_class_method :daily
end
