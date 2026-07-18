# Fans out a weather refresh for every location. Wired into config/recurring.yml
# to keep cached forecasts fresh, and also triggerable from the locations UI.
class RefreshAllWeatherJob < ApplicationJob
  queue_as :default

  def perform
    Location.find_each do |location|
      RefreshLocationWeatherJob.perform_later(location)
    end
  end
end
