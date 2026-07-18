module MapsHelper
  def mapbox_token
    Rails.application.credentials.dig(:mapbox_token)
  end

  # JSON payload of locations for the globe Stimulus controller. Each entry
  # carries the name (shown beside the marker) and the WMO condition code (the
  # front-end picks the SVG icon from it).
  def location_markers_json(locations)
    locations.map { |location|
      {
        name: location.name,
        latitude: location.latitude.to_f,
        longitude: location.longitude.to_f,
        condition_code: location.current_condition_code
      }
    }.to_json
  end
end
