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
    assert_equal "fahrenheit", read_signed_cookie(:temperature_unit)
  end

  test "update switches the wind unit" do
    patch settings_url, params: { wind_unit: "kph" }

    assert_response :redirect
    assert_equal "kph", read_signed_cookie(:wind_unit)
  end

  # Every visitor preference goes out through the same
  # ApplicationController#store_visitor_cookie, so checking one covers the shape
  # of all of them (units here, the closest location in the other suites).
  test "preferences are stored signed, httponly and permanent" do
    patch settings_url, params: { temperature_unit: "fahrenheit" }
    cookie = response.headers["set-cookie"].to_s

    assert_match(/httponly/i, cookie)
    assert_match(/expires=/i, cookie)
    assert_operator Time.parse(cookie[/expires=([^;]+)/i, 1]), :>, 1.year.from_now
    assert_no_match(/temperature_unit=fahrenheit/, cookie, "the value should be signed, not plain")
    assert_equal "fahrenheit", read_signed_cookie(:temperature_unit)
  end

  test "update ignores unknown units" do
    patch settings_url, params: { temperature_unit: "kelvin", wind_unit: "knots" }

    assert_response :redirect
    assert_nil read_signed_cookie(:temperature_unit)
    assert_nil read_signed_cookie(:wind_unit)
  end
end
