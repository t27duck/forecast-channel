# The way in: the Wii-style loading screen, which hands over to your own
# location's forecast — or, for someone who hasn't chosen one yet, to the
# picker. Deliberately no require_current_location: this is the screen every
# arrival lands on, including a shared link's preview, so it plays its beat for
# everyone rather than being skipped by a redirect.
class HomeController < ApplicationController
  allow_unauthenticated_access

  # Asked for as JSON, this starts the work the screen is covering — refreshing
  # weather that has gone stale — and answers immediately. The refresh itself
  # runs in a job, which broadcasts when it's done; the splash subscribes before
  # asking, and hands over on that signal rather than on a timer.
  #
  # Deliberately not synchronous any more: an Open-Meteo round trip held inside
  # the request parked one of the server's few threads for its whole duration,
  # and several people arriving at once could park most of them. `weather_stale?`
  # still gates the work — the job checks it again, since it can no longer be
  # the rate limit on its own once the answer stops waiting for the work.
  def show
    @location = current_location

    respond_to do |format|
      format.html { @refresh = stale_weather? }
      format.json { render json: { refreshing: enqueue_refresh } }
    end
  end

  private

  # Queue the refresh, and say whether there's anything to wait for. False when
  # the weather is already fresh, so the splash stops holding for a signal that
  # will never come.
  def enqueue_refresh
    return false unless stale_weather?

    RefreshLocationWeatherJob.perform_later(@location)
    true
  end

  # False rather than nil when nobody has chosen a location yet: Stimulus reads
  # any value but "0"/"false" as true, so a blank attribute would send the
  # splash off to refresh weather it hasn't got.
  def stale_weather?
    @location.present? && @location.weather_stale?
  end
end
