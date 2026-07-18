# Application-wide preferences. Modelled as a singleton row: there is exactly
# one Setting, fetched via Setting.current.
#
# Weather is always stored in Celsius (the canonical unit); the temperature_unit
# preference only affects how values are displayed, so switching units never
# requires re-fetching.
class Setting < ApplicationRecord
  enum :temperature_unit, { celsius: "celsius", fahrenheit: "fahrenheit" }, default: :celsius

  # The single settings row, created on first access.
  def self.current
    first || create!
  end

  def temperature_symbol
    fahrenheit? ? "°F" : "°C"
  end

  # Converts a canonical Celsius value into the preferred display unit.
  def convert_temperature(celsius)
    return nil if celsius.nil?

    fahrenheit? ? (celsius.to_f * 9.0 / 5.0 + 32.0) : celsius.to_f
  end
end
