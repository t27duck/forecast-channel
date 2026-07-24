module MapsHelper
  # The token the globe renders with. Blank in the test environment (see
  # config/environments/test.rb), where the globe controller falls back to an
  # offline style so system tests never reach api.mapbox.com — and behave the
  # same with or without credentials, as CI has none.
  def mapbox_token
    return nil if Rails.configuration.x.mapbox_token_disabled

    Rails.application.credentials.dig(:mapbox_token)
  end
end
