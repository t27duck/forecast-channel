module MapsHelper
  # Halloween's atmosphere for the globe: a burnt-orange horizon over a black
  # sky, with the stars turned up. A complete fog object, because Mapbox's
  # setFog replaces rather than merges — anything left out would fall back to
  # Mapbox's own default, not ours.
  #
  # The ordinary blue lives in the globe controller (DEFAULT_FOG) and is
  # deliberately not repeated here: this file only speaks up on the days the
  # calendar asks it to.
  HALLOWEEN_FOG = {
    "color" => "#d1601a",
    "high-color" => "#5b1a02",
    "space-color" => "#07030a",
    "star-intensity" => 0.95,
    "horizon-blend" => 0.05
  }.freeze

  # The token the globe renders with, read from the MAPBOX_TOKEN environment
  # variable (dotenv loads it from .env.development.local locally; Kamal injects
  # it in production). Blank in the test suite, which clears the variable (see
  # test/test_helper.rb) so the globe controller falls back to an offline style
  # and system tests never reach api.mapbox.com.
  #
  # `presence`, so the blank MAPBOX_TOKEN="" the example env files ship reads as
  # "no token" rather than as an empty one Mapbox would reject.
  def mapbox_token
    ENV["MAPBOX_TOKEN"].presence
  end

  # The globe's atmosphere when the calendar calls for something other than the
  # usual blue, as JSON for the controller's `fog` value. Nil on any ordinary
  # day, which is the whole year bar one — so the normal look keeps exactly one
  # home, in the JavaScript that draws it.
  def globe_fog_value
    return nil unless seasonal_theme&.key == "halloween"

    HALLOWEEN_FOG.to_json
  end

  # The tour's itinerary, for the globe controller's `tour` value: where to fly,
  # and which feature to read the weather card from on arrival.
  #
  # Coordinates have to be carried here — a city on the far side of the globe is
  # in no loaded tile, so the marker source can't be asked where it is. The
  # weather deliberately isn't: the slug looks the *live* feature up once the
  # camera has landed on it, so a card shows what the last refresh wrote rather
  # than what was true when the page was rendered.
  def tour_stops_value(locations)
    locations.map { |location|
      { slug: location.slug, lng: location.longitude.to_f, lat: location.latitude.to_f }
    }.to_json
  end
end
