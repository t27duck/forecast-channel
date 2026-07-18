module MapsHelper
  def mapbox_token
    Rails.application.credentials.dig(:mapbox_token)
  end
end
