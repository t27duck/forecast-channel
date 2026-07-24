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
      Location.find_by(id: cookies.signed[:current_location_id]) || Location.by_name.first
  end

  # The visitor's display preferences (temperature and wind units), read from
  # their browser cookies so each visitor keeps their own.
  def current_setting
    @current_setting ||= Setting.new(
      temperature_unit: cookies.signed[:temperature_unit],
      wind_unit: cookies.signed[:wind_unit]
    )
  end

  # Remembers which location is this visitor's closest.
  def store_current_location(location)
    store_visitor_cookie(:current_location_id, location.id)
  end

  # Every preference we keep for a visitor is stored the same way as the
  # session cookie (see Authentication#start_new_session_for): signed, so a
  # tampered value is rejected rather than trusted; httponly, since nothing in
  # the browser reads these — only the server does; and permanent, because a
  # preference someone set should outlive the browser session.
  def store_visitor_cookie(name, value)
    cookies.signed.permanent[name] = { value: value, httponly: true, same_site: :lax }
  end
end
