# Fetches current air quality for locations from Open-Meteo and writes it onto
# the records. Mirrors WeatherRefresher (a separate API, so a separate pass);
# a failed fetch leaves the locations' air-quality data untouched.
class AirQualityRefresher
  def self.call(location)
    new(location).call
  end

  # Refreshes many locations with batched requests, reusing the weather batch
  # size. Returns how many were updated; a chunk whose fetch fails is skipped.
  def self.call_many(locations)
    locations.each_slice(WeatherRefresher::BATCH_SIZE).sum { |chunk| refresh_chunk(chunk) }
  end

  def self.refresh_chunk(chunk)
    payloads = OpenMeteo::AirQualityClient.fetch_many(chunk.map(&:coordinates))
    return 0 if payloads.nil?

    chunk.zip(payloads).count do |location, payload|
      location.update!(OpenMeteo::AirQualityMapper.new(payload).attributes)
    end
  end
  private_class_method :refresh_chunk

  def initialize(location)
    @location = location
  end

  def call
    payload = OpenMeteo::AirQualityClient.fetch(
      latitude: @location.latitude, longitude: @location.longitude
    )
    return false if payload.nil?

    @location.update!(OpenMeteo::AirQualityMapper.new(payload).attributes)
    true
  end
end
