# The way in: the Wii-style loading screen, which hands over to your own
# location's forecast.
class HomeController < ApplicationController
  allow_unauthenticated_access
  before_action :require_current_location

  # Asked for as JSON, this does the work the screen is covering — refreshing
  # weather that has gone stale — and answers once it's done, so the splash can
  # wait for it. Synchronously, like LocationsController#refresh: OpenMeteo
  # requests are bounded and never raise, and the splash gives up on its own
  # anyway. `weather_stale?` doubles as the rate limit, since a location just
  # refreshed stays fresh for an hour.
  def show
    @location = current_location

    respond_to do |format|
      format.html { @refresh = @location.weather_stale? }
      format.json { render json: { refreshed: @location.weather_stale? && @location.refresh_weather! } }
    end
  end
end
