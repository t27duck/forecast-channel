class MapsController < ApplicationController
  def show
    @locations = Location.by_name
  end

  # GeoJSON feed of locations for the globe's symbol layer.
  def markers
    render json: LocationGeojson.feature_collection(Location.by_name)
  end
end
