module MapsHelper
  # The token the globe renders with, read from the MAPBOX_TOKEN environment
  # variable (dotenv loads it from .env.development locally; Kamal injects it in
  # production). Blank in the test environment (see config/environments/
  # test.rb), where the globe controller falls back to an offline style so
  # system tests never reach api.mapbox.com — and behave the same with or
  # without a token, as CI has none.
  #
  # `present?`, not truthiness: `config.x` answers a key nobody set with an
  # empty options object, which is truthy — testing it directly blanks the
  # token in every environment, test or not. `presence` on the variable itself,
  # so the blank MAPBOX_TOKEN="" the example env files ship reads as "no token"
  # rather than as an empty one Mapbox would reject.
  def mapbox_token
    return nil if Rails.configuration.x.mapbox_token_disabled.present?

    ENV["MAPBOX_TOKEN"].presence
  end
end
