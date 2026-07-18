require "test_helper"

class TemperaturesHelperTest < ActionView::TestCase
  test "formats in celsius by default" do
    assert_equal "18°C", display_temperature(18.0)
  end

  test "converts and formats in fahrenheit when preferred" do
    Setting.current.fahrenheit!
    assert_equal "64°F", display_temperature(18.0) # 18C -> 64.4F -> 64
  end

  test "shows an em dash for a missing temperature" do
    assert_equal "—", display_temperature(nil)
  end
end
