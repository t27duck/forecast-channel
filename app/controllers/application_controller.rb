class ApplicationController < ActionController::Base
  include Authentication
  include CurrentLocation
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_setting

  private

  # The visitor's display preferences (temperature and wind units), read from
  # their browser cookies so each visitor keeps their own.
  def current_setting
    @current_setting ||= Setting.new(
      temperature_unit: cookies.signed[:temperature_unit],
      wind_unit: cookies.signed[:wind_unit]
    )
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
