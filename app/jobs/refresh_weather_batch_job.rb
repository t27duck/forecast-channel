# Refreshes a chunk of locations with a single batched Open-Meteo request.
# Takes ids rather than records so locations deleted between enqueue and run
# simply drop out of the batch.
class RefreshWeatherBatchJob < ApplicationJob
  queue_as :default

  def perform(location_ids)
    WeatherRefresher.call_many(Location.where(id: location_ids).to_a)
  end
end
