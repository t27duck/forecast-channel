# The way in: the Wii-style loading screen, which hands over to your own
# location's forecast — or, for someone who hasn't chosen one yet, to the
# picker. Deliberately no require_current_location: this is the screen every
# arrival lands on, including a shared link's preview, so it plays its beat for
# everyone rather than being skipped by a redirect.
class HomeController < ApplicationController
  allow_unauthenticated_access

  # Asked for as JSON, this does the work the screen is covering — refreshing
  # weather that has gone stale — and answers once it's done, so the splash can
  # wait for it. Synchronously, like LocationsController#refresh: OpenMeteo
  # requests are bounded and never raise, and the splash gives up on its own
  # anyway. `weather_stale?` doubles as the rate limit, since a location just
  # refreshed stays fresh for an hour.
  def show
    @location = current_location

    respond_to do |format|
      format.html { @refresh = stale_weather? }
      format.json { render json: { refreshed: stale_weather? && @location.refresh_weather! } }
    end
  end

  private

  # False rather than nil when nobody has chosen a location yet: Stimulus reads
  # any value but "0"/"false" as true, so a blank attribute would send the
  # splash off to refresh weather it hasn't got.
  def stale_weather?
    @location.present? && @location.weather_stale?
  end
end
