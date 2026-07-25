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
end
