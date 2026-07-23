class SettingsController < ApplicationController
  allow_unauthenticated_access

  def show
    @setting = current_setting
    @current_location = current_location
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

  # Persists a submitted unit to a permanent cookie when it's a known value,
  # ignoring anything unrecognised.
  def store_unit(name, allowed)
    value = params[name]
    cookies.permanent[name] = value if allowed.include?(value)
  end
end
