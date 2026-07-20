# Fetches the latest weather for a Location from Open-Meteo and writes it onto
# the record. Returns true when the location was updated, false when the fetch
# failed (the location is left untouched).
class WeatherRefresher
  # Coordinates per Open-Meteo request. Chunking (rather than one huge request)
  # keeps a single bad coordinate or timeout from sinking the whole sweep.
  BATCH_SIZE = 50

  def self.call(location)
    new(location).call
  end

  # Refreshes many locations using batched requests — one request per chunk
  # instead of one per location. Returns how many were refreshed; a chunk whose
  # fetch fails is skipped, leaving those locations untouched.
  def self.call_many(locations)
    locations.each_slice(BATCH_SIZE).sum { |chunk| refresh_chunk(chunk) }
  end

  def self.refresh_chunk(chunk)
    payloads = OpenMeteo::ForecastClient.fetch_many(chunk.map(&:coordinates))
    return 0 if payloads.nil?

    chunk.zip(payloads).count do |location, payload|
      location.update!(OpenMeteo::WeatherMapper.new(payload).attributes)
    end
  end
  private_class_method :refresh_chunk

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
