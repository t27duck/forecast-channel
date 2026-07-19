class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  # The user's "closest" location — a current_location_id cookie (set on the
  # settings page) falling back to the first location. Shown at the root path.
  def current_location
    @current_location ||=
      Location.find_by(id: cookies[:current_location_id]) || Location.by_name.first
  end
end
