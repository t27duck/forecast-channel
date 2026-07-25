# The visitor's closest location: reading it, requiring it, and storing it.
#
# Included in ApplicationController, whose store_visitor_cookie writes the
# signed cookie this reads back.
module CurrentLocation
  extend ActiveSupport::Concern

  included do
    helper_method :current_location
  end

  private
    # The location this visitor chose, or nil when they haven't chosen one.
    # There is deliberately no fallback: "no location yet" is a real state that
    # first-time setup reacts to (see require_current_location).
    def current_location
      @current_location ||= Location.find_by(id: cookies.signed[:current_location_id])
    end

    # Visitor-facing screens declare this as a before_action, so until someone
    # tells us where they live the picker is the only page they can reach.
    # Opt-in rather than global: it's a first-run flow, not a security
    # boundary, and every controller inheriting ApplicationController includes
    # the admin-only ones and Mission Control's dashboard, which have no
    # business asking for a location.
    def require_current_location
      redirect_to settings_location_path unless current_location
    end

    # Remembers which location is this visitor's closest.
    def store_current_location(location)
      store_visitor_cookie(:current_location_id, location.id)
      store_regional_units(location)
    end

    # Somebody who has never chosen units gets the ones their new location's
    # country actually uses; a unit they picked themselves is left alone.
    def store_regional_units(location)
      Setting.units_for(location.country_code).each do |name, value|
        store_visitor_cookie(name, value) if cookies.signed[name].blank?
      end
    end
end
