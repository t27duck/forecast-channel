# Per-visitor display preferences (temperature and wind units). Stored in the
# visitor's browser cookies rather than the database, so every visitor keeps
# their own units; built from those cookie values by
# ApplicationController#current_setting.
#
# Weather is always stored in Celsius/km-h (the canonical units); these
# preferences only affect how values are displayed, so switching units never
# requires re-fetching. Unknown or missing units fall back to the defaults.
class Setting
  TEMPERATURE_UNITS = %w[celsius fahrenheit].freeze
  WIND_UNITS = %w[mph kph].freeze

  DEFAULT_TEMPERATURE_UNIT = "celsius"
  DEFAULT_WIND_UNIT = "mph"

  # The units these countries actually use day to day, keyed by ISO-2 code.
  # Only the units worth writing are listed, so choosing a location anywhere
  # else leaves the visitor on the defaults.
  REGIONAL_UNITS = {
    "US" => { temperature_unit: "fahrenheit", wind_unit: "mph" },
    "LR" => { temperature_unit: "fahrenheit" },
    "KY" => { temperature_unit: "fahrenheit" },
    "GB" => { wind_unit: "mph" }
  }.freeze

  # The units to seed for someone whose closest location is in this country.
  def self.units_for(country_code)
    REGIONAL_UNITS.fetch(country_code, {})
  end

  attr_reader :temperature_unit, :wind_unit

  def initialize(temperature_unit: nil, wind_unit: nil)
    @temperature_unit = TEMPERATURE_UNITS.include?(temperature_unit) ? temperature_unit : DEFAULT_TEMPERATURE_UNIT
    @wind_unit = WIND_UNITS.include?(wind_unit) ? wind_unit : DEFAULT_WIND_UNIT
  end

  def celsius? = temperature_unit == "celsius"
  def fahrenheit? = temperature_unit == "fahrenheit"
  def mph? = wind_unit == "mph"
  def kph? = wind_unit == "kph"

  def temperature_symbol
    fahrenheit? ? "°F" : "°C"
  end

  # Converts a canonical Celsius value into the preferred display unit.
  def convert_temperature(celsius)
    return nil if celsius.nil?

    fahrenheit? ? (celsius.to_f * 9.0 / 5.0 + 32.0) : celsius.to_f
  end
end
