require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "current returns the singleton row" do
    assert_equal settings(:default), Setting.current
    assert_no_difference("Setting.count") { Setting.current }
  end

  test "defaults to celsius and mph" do
    assert_predicate Setting.new, :celsius?
    assert_predicate Setting.new, :mph?
  end

  test "convert_temperature keeps celsius and formats the symbol" do
    setting = settings(:default)
    assert_in_delta 18.0, setting.convert_temperature(18.0)
    assert_equal "°C", setting.temperature_symbol
  end

  test "convert_temperature converts to fahrenheit" do
    setting = settings(:default)
    setting.fahrenheit!

    assert_in_delta 32.0, setting.convert_temperature(0)
    assert_in_delta 98.6, setting.convert_temperature(37)
    assert_equal "°F", setting.temperature_symbol
  end

  test "convert_temperature passes through nil" do
    assert_nil settings(:default).convert_temperature(nil)
  end
end
