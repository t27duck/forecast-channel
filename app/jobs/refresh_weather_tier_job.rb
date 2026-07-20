# Refreshes one refresh tier, scheduled at its own cadence in
# config/recurring.yml: "hot" (big cities and anywhere recently viewed) hourly,
# "cold" (everywhere else) a few times a day.
class RefreshWeatherTierJob < ApplicationJob
  queue_as :default

  TIERS = %w[hot cold].freeze

  def perform(tier)
    raise ArgumentError, "unknown refresh tier #{tier.inspect}" unless TIERS.include?(tier)

    Location.public_send(tier).ids.each_slice(WeatherRefresher::BATCH_SIZE) do |ids|
      RefreshWeatherBatchJob.perform_later(ids)
    end
  end
end
