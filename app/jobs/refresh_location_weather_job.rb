# Refreshes the cached weather for a single Location.
class RefreshLocationWeatherJob < ApplicationJob
  queue_as :default

  # The location may have been deleted between enqueue and run.
  discard_on ActiveJob::DeserializationError

  def perform(location)
    WeatherRefresher.call(location)
  end
end
