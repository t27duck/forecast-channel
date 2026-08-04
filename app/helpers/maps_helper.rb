module MapsHelper
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
