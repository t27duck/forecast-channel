# Sets the closest-location cookie from browser-provided coordinates (the
# auto-detect on first visit), then shows that location's forecast.
class CurrentLocationsController < ApplicationController
  def create
    location = Location.nearest_to(params[:latitude], params[:longitude])
    cookies.permanent[:current_location_id] = location.id if location

    redirect_to root_path
  end
end
