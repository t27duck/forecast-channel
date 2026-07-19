# Serializes locations into a GeoJSON FeatureCollection for the globe's symbol
# layer. Each feature carries the icon group (chosen from the weather code) and
# population, which the layer uses as a collision priority so larger cities win
# when markers overlap.
class LocationGeojson
  def self.feature_collection(locations)
    {
      type: "FeatureCollection",
      features: locations.map { |location| feature(location) }
    }
  end

  def self.feature(location)
    current_icon = WeatherCode.icon_group(location.current_condition_code)
    today = location.today_forecast
    tomorrow = location.tomorrow_forecast

    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [ location.longitude.to_f, location.latitude.to_f ]
      },
      properties: {
        id: location.id,
        name: location.name,
        # One icon per globe view (current / today / tomorrow); the layer swaps
        # which one it renders as the user cycles the "Next" button.
        icon: current_icon,
        icon_today: forecast_icon(today, current_icon),
        icon_tomorrow: forecast_icon(tomorrow, current_icon),
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
