# Sets the closest-location cookie from browser-provided coordinates (the
# auto-detect on first visit), then shows that location's forecast.
class CurrentLocationsController < ApplicationController
  allow_unauthenticated_access
  def create
    location = Location.nearest_to(params[:latitude], params[:longitude])
    store_current_location(location) if location

    redirect_to root_path
  end
end
