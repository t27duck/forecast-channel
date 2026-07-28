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
    # Per location rather than one signal everyone acts on: a forecast screen
    # only cares about the place it's showing, and re-rendering every open one
    # for a chunk that didn't contain it would cost a request each time.
    locations.each { |location| WeatherBroadcast.forecast_refreshed(location) }
  end
end
