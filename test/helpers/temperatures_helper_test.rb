require "test_helper"

class TemperaturesHelperTest < ActionView::TestCase
  # In views current_setting is a controller helper reading cookies; supply a
  # stand-in here so the formatting helpers can be exercised directly.
  attr_writer :current_setting

  def current_setting
    @current_setting ||= Setting.new
  end

  test "formats in celsius by default" do
    assert_equal "18°C", display_temperature(18.0)
  end

  test "converts and formats in fahrenheit when preferred" do
    self.current_setting = Setting.new(temperature_unit: "fahrenheit")
    assert_equal "64°F", display_temperature(18.0) # 18C -> 64.4F -> 64
  end

  test "shows an em dash for a missing temperature" do
    assert_equal "—", display_temperature(nil)
  end
end
