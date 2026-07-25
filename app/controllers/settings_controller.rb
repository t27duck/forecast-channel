class SettingsController < ApplicationController
  allow_unauthenticated_access
  # Only #show: #update also backs the °C/°F toggle on the locations index,
  # which has nothing to do with having chosen a closest location.
  before_action :require_current_location, only: %i[show]

  def show
    @setting = current_setting
  end

  # Stores the temperature or wind unit (whichever was submitted) in a cookie,
  # then returns where the user came from. Also serves the °C/°F toggle on the
  # locations index. The closest location is chosen via
  # Settings::LocationsController.
  def update
    store_unit(:temperature_unit, Setting::TEMPERATURE_UNITS)
    store_unit(:wind_unit, Setting::WIND_UNITS)

    redirect_back fallback_location: settings_path
  end

  private

  # Persists a submitted unit to the visitor's cookie when it's a known value,
  # ignoring anything unrecognised.
  def store_unit(name, allowed)
    value = params[name]
    store_visitor_cookie(name, value) if allowed.include?(value)
  end
end
