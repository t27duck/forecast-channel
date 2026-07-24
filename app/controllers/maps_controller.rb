class MapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @locations = Location.by_name
    # When arriving from a location's forecast, centre the globe on it.
    @focus = Location.find_by(slug: params[:location])
  end

  # GeoJSON feed of locations for the globe's symbol layer.
  def markers
    render json: LocationGeojson.feature_collection(Location.by_name)
  end
end
