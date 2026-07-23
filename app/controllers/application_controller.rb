class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_setting

  private

  # The user's "closest" location — a current_location_id cookie (set on the
  # settings page) falling back to the first location. Shown at the root path.
  def current_location
    @current_location ||=
      Location.find_by(id: cookies[:current_location_id]) || Location.by_name.first
  end

  # The visitor's display preferences (temperature and wind units), read from
  # their browser cookies so each visitor keeps their own.
  def current_setting
    @current_setting ||= Setting.new(
      temperature_unit: cookies[:temperature_unit],
      wind_unit: cookies[:wind_unit]
    )
  end
end
