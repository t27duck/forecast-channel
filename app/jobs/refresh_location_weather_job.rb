# Refreshes the cached weather for a single Location, then says so — the splash
# holds its beat until this broadcast arrives (see HomeController#show).
class RefreshLocationWeatherJob < ApplicationJob
  queue_as :default

  # The location may have been deleted between enqueue and run.
  discard_on ActiveJob::DeserializationError

  def perform(location)
    # refresh_weather!, not WeatherRefresher on its own, so air quality comes
    # along with it — the refresh this replaced ran inside the request and did
    # both. The staleness check is repeated from the enqueue side because it
    # can't be the rate limit any more now the work is asynchronous: two
    # arrivals in the same second would both find stale weather and both
    # enqueue. Whoever runs second finds it fresh, and only answers.
    refreshed = location.weather_stale? && location.refresh_weather!

    # Only when something actually changed: an open forecast screen re-requests
    # its page to act on this, which is wasted work if the reading is the same.
    WeatherBroadcast.forecast_refreshed(location) if refreshed

    # This one unconditionally: the splash wants to know the attempt is over,
    # not whether Open-Meteo had anything new. A failed fetch renders the
    # weather already stored, which is what it would have shown anyway.
    WeatherBroadcast.location_ready(location)
  end
end
