class SettingsController < ApplicationController
  # Toggle the global temperature unit, then return where the user came from.
  def update
    unit = params[:temperature_unit]
    Setting.current.update!(temperature_unit: unit) if Setting.temperature_units.key?(unit)

    redirect_back fallback_location: locations_path
  end
end
