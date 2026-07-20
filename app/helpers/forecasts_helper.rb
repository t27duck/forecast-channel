module ForecastsHelper
  KMH_TO_MPH = 0.621371
  COMPASS = %w[N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW].freeze

  # The four 6-hour windows of a day, with their display time ranges. Order is
  # fixed so the overlay always shows overnight → morning → afternoon → evening.
  SIX_HOUR_WINDOWS = [
    { key: "overnight", from: "12:00 a.m.", to: "6:00 a.m." },
    { key: "morning",   from: "6:00 a.m.",  to: "12:00 p.m." },
    { key: "afternoon", from: "12:00 p.m.", to: "6:00 p.m." },
    { key: "evening",   from: "6:00 p.m.",  to: "12:00 a.m." }
  ].freeze

  # The four windows for a day ("today"/"tomorrow"), each with its time labels
  # and the stored data (nil when that window has no forecast yet).
  def six_hour_windows(location, day)
    stored = location.hourly_windows.select { |w| w["day"] == day }.index_by { |w| w["window"] }
    SIX_HOUR_WINDOWS.map { |window| window.merge(data: stored[window[:key]]) }
  end

  # Full uppercase weekday name for an ISO date string, e.g. "THURSDAY".
  def weekday_name(date_string)
    return nil if date_string.blank?

    Date.parse(date_string).strftime("%A").upcase
  rescue Date::Error
    nil
  end

  # Wii-style temperature: the value in the viewer's unit, with a degree sign
  # (e.g. "89°") unless +degree: false+ (the 5-day panel shows bare numbers).
  # No unit letter, mirroring the Wii. Returns +fallback+ when missing.
  def forecast_temperature(celsius, fallback: "--", degree: true)
    return fallback if celsius.nil?

    value = number_with_precision(Setting.current.convert_temperature(celsius), precision: 0)
    degree ? "#{value}°" : value
  end

  # Clock time from an Open-Meteo local timestamp like "2026-07-20T05:12",
  # e.g. "5:12 a.m." The stamp is already in the location's local time, so only
  # the wall-clock portion is formatted. Nil when missing or unparseable.
  def forecast_time(iso_local)
    return nil if iso_local.blank?

    Time.parse(iso_local).strftime("%-l:%M %p").sub("AM", "a.m.").sub("PM", "p.m.")
  rescue ArgumentError
    nil
  end

  # "Feels like" range for a day's forecast, e.g. "26° / 15°". Nil when the
  # apparent temperatures are missing.
  def apparent_range(forecast)
    high = forecast["apparent_high"]
    low = forecast["apparent_low"]
    return nil if high.nil? && low.nil?

    "#{forecast_temperature(high)} / #{forecast_temperature(low)}"
  end

  # 16-point compass label for a wind bearing in degrees, e.g. 160 -> "SSE".
  def compass_direction(degrees)
    return nil if degrees.nil?

    COMPASS[((degrees.to_f / 22.5) + 0.5).floor % 16]
  end

  # Wind readout like "SSE 16 mph" in the preferred unit (speed stored in
  # km/h). Nil when no speed.
  def wind_display(speed_kmh, degrees)
    return nil if speed_kmh.nil?

    if Setting.current.kph?
      speed = "#{speed_kmh.to_f.round} kph"
    else
      speed = "#{(speed_kmh.to_f * KMH_TO_MPH).round} mph"
    end
    [ compass_direction(degrees), speed ].compact.join(" ")
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
