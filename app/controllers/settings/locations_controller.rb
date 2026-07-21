# Wii-style closest-location picker: choose a country, then — for a country with
# many locations, like the US — a state/region, then a location in it.
class Settings::LocationsController < ApplicationController
  # A country with more locations than this gets an intermediate state/region
  # step, so its final list of cities isn't an overwhelming scroll.
  STATE_STEP_THRESHOLD = 15

  def show
    if params[:country].blank?
      @countries = Location.where.not(country: [ nil, "" ]).distinct.order(:country).pluck(:country)
      return
    end

    @country = params[:country]
    countrywide = Location.where(country: @country)

    if params[:state].present?
      @state = params[:state]
      @locations = countrywide.where(admin1: @state).by_name
    elsif state_step?(countrywide)
      @states = countrywide.where.not(admin1: [ nil, "" ]).distinct.order(:admin1).pluck(:admin1)
    else
      @locations = countrywide.by_name
    end
  end

  def update
    id = params[:current_location_id]
    cookies.permanent[:current_location_id] = id if id.present? && Location.exists?(id)

    # No flash: the settings page is full-height, and a banner above it would
    # push the footer off-screen. The updated closest location shows there anyway.
    redirect_to settings_path
  end

  private

  # A big country spread across several states/regions gets the extra step.
  def state_step?(scope)
    scope.count > STATE_STEP_THRESHOLD &&
      scope.where.not(admin1: [ nil, "" ]).distinct.count(:admin1) > 1
  end
end
