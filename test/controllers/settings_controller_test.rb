require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "update switches the temperature unit" do
    patch settings_url, params: { temperature_unit: "fahrenheit" }

    assert_response :redirect
    assert_predicate Setting.current, :fahrenheit?
  end

  test "update ignores an unknown unit" do
    patch settings_url, params: { temperature_unit: "kelvin" }

    assert_response :redirect
    assert_predicate Setting.current, :celsius?
  end
end
