# The way in. Today it hands straight over to your own location's forecast;
# a Wii-style splash screen would live here.
class HomeController < ApplicationController
  allow_unauthenticated_access
  before_action :require_current_location

  def show
    redirect_to location_path(current_location)
  end
end
