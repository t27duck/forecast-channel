require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { write_signed_cookie(:current_location_id, locations(:berlin).id) }

  test "show renders the settings screen" do
    get settings_url
    assert_response :success
    assert_select ".settings__header", text: "Change Settings"
    assert_select ".settings__value", text: locations(:berlin).name
    # Straight to the forecast, so coming back doesn't replay the splash.
    assert_select ".wii-bottom a[href=?]", location_path(locations(:berlin)), text: "Back"
  end

  test "show offers a Sound row wired to the jukebox" do
    get settings_url

    assert_select ".settings__row[data-controller=mute][data-mute-jukebox-outlet=?]", "#jukebox" do
      assert_select ".settings__label", text: "Sound"
      assert_select "[data-mute-target=label]"
      assert_select "button[data-action=?]", "mute#toggle", text: "Change"
    end
  end

  test "the settings screen plays no music" do
    get settings_url
    assert_select "body[data-music-zone=?]", "silent"
  end

  test "show waits until a closest location has been chosen" do
    forget_cookie(:current_location_id)

    get settings_url
    assert_redirected_to settings_location_path
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
