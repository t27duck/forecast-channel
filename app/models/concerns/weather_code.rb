# Maps Open-Meteo WMO weather interpretation codes to human-readable labels.
#
# This is the single source of truth for turning a stored `condition_code`
# into a label, shared by the views today and by the weather-refresh task
# later so both agree on wording.
#
# Reference: https://open-meteo.com/en/docs (WMO Weather interpretation codes)
module WeatherCode
  LABELS = {
    0 => "Clear sky",
    1 => "Mainly clear",
    2 => "Partly cloudy",
    3 => "Overcast",
    45 => "Fog",
    48 => "Depositing rime fog",
    51 => "Light drizzle",
    53 => "Moderate drizzle",
    55 => "Dense drizzle",
    56 => "Light freezing drizzle",
    57 => "Dense freezing drizzle",
    61 => "Slight rain",
    63 => "Moderate rain",
    65 => "Heavy rain",
    66 => "Light freezing rain",
    67 => "Heavy freezing rain",
    71 => "Slight snowfall",
    73 => "Moderate snowfall",
    75 => "Heavy snowfall",
    77 => "Snow grains",
    80 => "Slight rain showers",
    81 => "Moderate rain showers",
    82 => "Violent rain showers",
    85 => "Slight snow showers",
    86 => "Heavy snow showers",
    95 => "Thunderstorm",
    96 => "Thunderstorm with slight hail",
    99 => "Thunderstorm with heavy hail"
  }.freeze

  UNKNOWN_LABEL = "Unknown"

  # Groups whose icon differs at night (a sun becomes a moon). Cloudy/precip
  # groups hide the sky, so they look the same day or night.
  NIGHT_ICON_GROUPS = %w[clear partly].freeze

  # Returns the human-readable label for a WMO code, or "Unknown" when the
  # code is nil or unrecognized.
  def self.label_for(code)
    return UNKNOWN_LABEL if code.nil?

    LABELS.fetch(code.to_i, UNKNOWN_LABEL)
  end

  # Coarse group used to pick a weather icon on the globe. Names match the keys
  # in app/javascript/lib/weather_icons.js. When it's night at the location
  # (`is_day: false`), clear/partly groups return their "_night" variant.
  def self.icon_group(code, is_day: true)
    return "unknown" if code.nil?

    group = base_icon_group(code.to_i)
    return "#{group}_night" if !is_day && NIGHT_ICON_GROUPS.include?(group)

    group
  end

  def self.base_icon_group(code)
    case code
    when 0, 1 then "clear"
    when 2 then "partly"
    when 3 then "overcast"
    when 45, 48 then "fog"
    when 51..67, 80..82 then "rain"
    when 71..77, 85, 86 then "snow"
    when 95.. then "thunder"
    else "unknown"
    end
  end
  private_class_method :base_icon_group
end
