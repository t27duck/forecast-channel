module OpenMeteo
  # Transforms an Open-Meteo forecast payload into the attributes stored on a
  # Location. Pure and side-effect free — hand it a parsed payload and read
  # #attributes.
  class WeatherMapper
    # The four 6-hour windows of a day, keyed by the local hour they cover.
    WINDOWS = [
      { key: "overnight", hours: 0...6 },
      { key: "morning",   hours: 6...12 },
      { key: "afternoon", hours: 12...18 },
      { key: "evening",   hours: 18...24 }
    ].freeze

    FORECAST_DAYS = 5

    def initialize(payload)
      @payload = payload || {}
    end

    def attributes
      {
        current_temperature: round(current["temperature_2m"], 1),
        current_humidity: current["relative_humidity_2m"]&.round,
        current_precipitation_probability: current["precipitation_probability"]&.round,
        current_condition_code: current_code,
        current_condition_label: WeatherCode.label_for(current_code),
        current_wind_speed: round(current["wind_speed_10m"], 1),
        current_wind_direction: current["wind_direction_10m"]&.round,
        uv_index: round(current["uv_index"], 1),
        uv_label: UvIndex.label_for(current["uv_index"]),
        today_forecast: daily_forecast(0),
        tomorrow_forecast: daily_forecast(1),
        hourly_windows: hourly_windows,
        five_day_forecast: five_day_forecast,
        weather_refreshed_at: Time.current
      }
    end

    private

    def current
      @payload["current"] || {}
    end

    def daily
      @payload["daily"] || {}
    end

    def hourly
      @payload["hourly"] || {}
    end

    def current_code
      current["weather_code"]&.to_i
    end

    # A single day's summary from the daily arrays; {} when out of range.
    def daily_forecast(index)
      dates = daily["time"]
      return {} if dates.nil? || dates[index].nil?

      code = daily["weather_code"]&.dig(index)&.to_i
      {
        "date" => dates[index],
        "high" => round(daily["temperature_2m_max"]&.dig(index)),
        "low" => round(daily["temperature_2m_min"]&.dig(index)),
        "condition_code" => code,
        "condition_label" => WeatherCode.label_for(code),
        "wind_speed" => round(daily["wind_speed_10m_max"]&.dig(index), 1),
        "wind_direction" => daily["wind_direction_10m_dominant"]&.dig(index)&.round
      }
    end

    def five_day_forecast
      dates = daily["time"] || []
      (0...[ dates.size, FORECAST_DAYS ].min).map { |index| daily_forecast(index) }
    end

    # 6-hour window summaries for today (day 0) and tomorrow (day 1).
    def hourly_windows
      return [] if hourly["time"].blank? || daily["time"].blank?

      [ [ 0, "today" ], [ 1, "tomorrow" ] ].flat_map do |day_index, day_label|
        date = daily["time"][day_index]
        next [] if date.nil?

        WINDOWS.filter_map { |window| window_summary(date, day_label, window) }
      end
    end

    def window_summary(date, day_label, window)
      indices = hourly_indices(date, window[:hours])
      return nil if indices.empty?

      temps = indices.filter_map { |i| hourly["temperature_2m"][i] }
      code = indices.filter_map { |i| hourly["weather_code"][i] }.max&.to_i

      {
        "day" => day_label,
        "window" => window[:key],
        "temperature" => temps.any? ? (temps.sum / temps.size).round : nil,
        "condition_code" => code,
        "condition_label" => WeatherCode.label_for(code)
      }
    end

    # Indices of hourly readings on +date+ whose local hour falls in +hours+.
    # Timestamps look like "2026-07-18T14:00".
    def hourly_indices(date, hours)
      times = hourly["time"]
      times.each_index.select do |i|
        stamp = times[i]
        stamp.start_with?(date) && hours.include?(stamp[11, 2].to_i)
      end
    end

    def round(value, digits = 0)
      return nil if value.nil?

      value.to_f.round(digits)
    end
  end
end
