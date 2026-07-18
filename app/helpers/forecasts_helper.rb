module ForecastsHelper
  KMH_TO_MPH = 0.621371
  COMPASS = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW].freeze

  # Wii-style temperature: the value in the viewer's unit, with a degree sign
  # (e.g. "89°") unless +degree: false+ (the 5-day panel shows bare numbers).
  # No unit letter, mirroring the Wii. Returns +fallback+ when missing.
  def forecast_temperature(celsius, fallback: "--", degree: true)
    return fallback if celsius.nil?

    value = number_with_precision(Setting.current.convert_temperature(celsius), precision: 0)
    degree ? "#{value}°" : value
  end

  # 16-point compass label for a wind bearing in degrees, e.g. 160 -> "SSE".
  def compass_direction(degrees)
    return nil if degrees.nil?

    COMPASS[((degrees.to_f / 22.5) + 0.5).floor % 16]
  end

  # Wind readout like "SSE 16 mph" (speed stored in km/h). Nil when no speed.
  def wind_display(speed_kmh, degrees)
    return nil if speed_kmh.nil?

    mph = (speed_kmh.to_f * KMH_TO_MPH).round
    [ compass_direction(degrees), "#{mph} mph" ].compact.join(" ")
  end

  # "As of 3:00 p.m., 05/12" in the location's local time.
  def as_of(time, timezone = nil)
    return nil if time.nil?

    local = timezone.present? ? time.in_time_zone(timezone) : time
    clock = local.strftime("%-l:%M %p").sub("AM", "a.m.").sub("PM", "p.m.")
    "As of #{clock}, #{local.strftime("%m/%d")}"
  end

  # Uppercase weekday abbreviation for an ISO date string, e.g. "SAT".
  def weekday_abbr(date_string)
    return nil if date_string.blank?

    Date.parse(date_string).strftime("%a").upcase
  rescue Date::Error
    nil
  end
end
