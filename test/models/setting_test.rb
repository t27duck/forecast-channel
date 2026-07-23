require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "defaults to celsius and mph" do
    setting = Setting.new
    assert_predicate setting, :celsius?
    assert_predicate setting, :mph?
  end

  test "reads the supplied units" do
    setting = Setting.new(temperature_unit: "fahrenheit", wind_unit: "kph")
    assert_predicate setting, :fahrenheit?
    assert_predicate setting, :kph?
  end

  test "falls back to the defaults for unknown or missing units" do
    setting = Setting.new(temperature_unit: "kelvin", wind_unit: "knots")
    assert_predicate setting, :celsius?
    assert_predicate setting, :mph?
  end

  test "convert_temperature keeps celsius and formats the symbol" do
    setting = Setting.new
    assert_in_delta 18.0, setting.convert_temperature(18.0)
    assert_equal "°C", setting.temperature_symbol
  end

  test "convert_temperature converts to fahrenheit" do
    setting = Setting.new(temperature_unit: "fahrenheit")
    assert_in_delta 32.0, setting.convert_temperature(0)
    assert_in_delta 98.6, setting.convert_temperature(37)
    assert_equal "°F", setting.temperature_symbol
  end

  test "convert_temperature passes through nil" do
    assert_nil Setting.new.convert_temperature(nil)
  end
end
