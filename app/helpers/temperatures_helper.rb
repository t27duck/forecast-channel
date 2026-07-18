module TemperaturesHelper
  # The current application settings (temperature unit, etc.).
  def current_setting
    Setting.current
  end

  # Formats a canonical Celsius value in the preferred display unit, e.g.
  # "18°C" or "64°F". Returns an em dash when the value is missing.
  def display_temperature(celsius, precision: 0)
    setting = current_setting
    value = setting.convert_temperature(celsius)
    return "—" if value.nil?

    "#{number_with_precision(value, precision: precision)}#{setting.temperature_symbol}"
  end
end
