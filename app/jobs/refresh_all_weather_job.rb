# Refreshes every location, in batches. Backs the "Refresh all" button in the
# locations UI; the recurring schedule uses RefreshWeatherTierJob instead so the
# long tail doesn't get refreshed as often as the places people look at.
class RefreshAllWeatherJob < ApplicationJob
  queue_as :default

  def perform
    Location.ids.each_slice(WeatherRefresher::BATCH_SIZE) do |ids|
      RefreshWeatherBatchJob.perform_later(ids)
    end
  end
end
