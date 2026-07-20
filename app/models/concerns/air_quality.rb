# Maps a US Air Quality Index value to its EPA category label and a colour key.
# The single source of truth for turning a stored `air_quality_index` into words,
# shared by the mapper (which caches the label) and the air-quality panel.
#
# https://www.airnow.gov/aqi/aqi-basics/
module AirQuality
  UNKNOWN_LABEL = "Unknown"

  # EPA category for a US AQI value (0–500).
  def self.label_for(value)
    return UNKNOWN_LABEL if value.nil?

    case value.to_i
    when ..50 then "Good"
    when 51..100 then "Moderate"
    when 101..150 then "Unhealthy for sensitive groups"
    when 151..200 then "Unhealthy"
    when 201..300 then "Very unhealthy"
    else "Hazardous"
    end
  end

  # A short key for CSS colour-coding, matching the EPA banding.
  def self.key_for(value)
    return "unknown" if value.nil?

    case value.to_i
    when ..50 then "good"
    when 51..100 then "moderate"
    when 101..150 then "sensitive"
    when 151..200 then "unhealthy"
    when 201..300 then "very-unhealthy"
    else "hazardous"
    end
  end
end
