module OpenMeteo
  # Shapes an Open-Meteo air-quality payload into the air-quality attributes
  # stored on a Location. Pure and side-effect free, mirroring WeatherMapper.
  class AirQualityMapper
    def initialize(payload)
      @payload = payload || {}
    end

    def attributes
      {
        air_quality_index: current["us_aqi"]&.round,
        air_quality_label: AirQuality.label_for(current["us_aqi"]),
        air_quality_pm2_5: round(current["pm2_5"], 1)
      }
    end

    private

    def current
      @payload["current"] || {}
    end

    def round(value, digits = 0)
      return nil if value.nil?

      value.to_f.round(digits)
    end
  end
end
