# Fetches the latest weather for a Location from Open-Meteo and writes it onto
# the record. Returns true when the location was updated, false when the fetch
# failed (the location is left untouched).
class WeatherRefresher
  def self.call(location)
    new(location).call
  end

  def initialize(location)
    @location = location
  end

  def call
    payload = OpenMeteo::ForecastClient.fetch(
      latitude: @location.latitude, longitude: @location.longitude
    )
    return false if payload.nil?

    @location.update!(OpenMeteo::WeatherMapper.new(payload).attributes)
    true
  end
end
