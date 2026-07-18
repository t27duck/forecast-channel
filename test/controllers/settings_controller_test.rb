require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "show renders the settings screen" do
    get settings_url
    assert_response :success
    assert_select ".settings__header", text: "Change Settings"
  end

  test "update switches the temperature unit" do
    patch settings_url, params: { temperature_unit: "fahrenheit" }

    assert_response :redirect
    assert_predicate Setting.current, :fahrenheit?
  end

  test "update switches the wind unit" do
    patch settings_url, params: { wind_unit: "kph" }

    assert_response :redirect
    assert_predicate Setting.current, :kph?
  end

  test "update ignores unknown units" do
    patch settings_url, params: { temperature_unit: "kelvin", wind_unit: "knots" }

    assert_response :redirect
    assert_predicate Setting.current, :celsius?
    assert_predicate Setting.current, :mph?
  end
end
