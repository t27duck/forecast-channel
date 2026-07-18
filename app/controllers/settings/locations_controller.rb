# Wii-style closest-location picker: choose a country, then a location in it.
class Settings::LocationsController < ApplicationController
  def show
    if params[:country].present?
      @country = params[:country]
      @locations = Location.where(country: @country).by_name
    else
      @countries = Location.where.not(country: [ nil, "" ]).distinct.order(:country).pluck(:country)
    end
  end

  def update
    id = params[:current_location_id]
    cookies.permanent[:current_location_id] = id if id.present? && Location.exists?(id)

    redirect_to settings_path, notice: "Closest location updated."
  end
end
