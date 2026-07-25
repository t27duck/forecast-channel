# Sets the closest-location cookie from browser-provided coordinates, posted by
# the "Use My Current Location" row on the picker (see geolocate_controller.js).
class CurrentLocationsController < ApplicationController
  allow_unauthenticated_access

  def create
    location = Location.nearest_to(params[:latitude], params[:longitude])

    if location
      store_current_location(location)
      redirect_to settings_path
    else
      # Nothing to be near — back to the picker to choose by hand.
      redirect_to settings_location_path
    end
  end
end
