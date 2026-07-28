# Refreshes a chunk of locations with a single batched Open-Meteo request.
# Takes ids rather than records so locations deleted between enqueue and run
# simply drop out of the batch.
class RefreshWeatherBatchJob < ApplicationJob
  queue_as :default

  def perform(location_ids)
    locations = Location.where(id: location_ids).to_a
    refreshed = WeatherRefresher.call_many(locations)
    AirQualityRefresher.call_many(locations)

    # Both refreshers count what they actually wrote, so a chunk whose fetch
    # failed — leaving every record untouched — tells nobody there's news.
    return unless refreshed.positive?

    WeatherBroadcast.batch_refreshed
    # "Refresh all" fans out into a chunk per BATCH_SIZE and then only leaves an
    # optimistic flash behind, so the index watches its rows land instead.
    WeatherBroadcast.index_refreshed
  end
end
