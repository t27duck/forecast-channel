class SettingsController < ApplicationController
  def show
    @setting = Setting.current
    @current_location = current_location
  end

  # Updates the temperature or wind unit (whichever was submitted), then returns
  # where the user came from. Also serves the °C/°F toggle on the locations
  # index. The closest location is chosen via Settings::LocationsController.
  def update
    update_temperature_unit
    update_wind_unit

    redirect_back fallback_location: settings_path
  end

  private

  def update_temperature_unit
    unit = params[:temperature_unit]
    Setting.current.update!(temperature_unit: unit) if Setting.temperature_units.key?(unit)
  end

  def update_wind_unit
    unit = params[:wind_unit]
    Setting.current.update!(wind_unit: unit) if Setting.wind_units.key?(unit)
  end
end
