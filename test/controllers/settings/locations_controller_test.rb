require "test_helper"

class Settings::LocationsControllerTest < ActionDispatch::IntegrationTest
  test "show lists the distinct countries" do
    get settings_location_url
    assert_response :success
    assert_select ".picker__prompt", /country/
    assert_select ".picker__row", text: locations(:berlin).country # Germany
    assert_select ".picker__row", text: locations(:tokyo).country  # Japan
  end

  test "show lists the locations in a chosen country" do
    get settings_location_url(country: locations(:berlin).country)
    assert_response :success
    assert_select ".picker__prompt", /location/
    assert_select ".picker__row", text: locations(:berlin).name
    assert_select ".picker__row", { count: 0, text: locations(:tokyo).name }
  end

  test "update stores the closest location in a cookie and returns to settings" do
    patch settings_location_url, params: { current_location_id: locations(:tokyo).id }

    assert_redirected_to settings_path
    assert_equal locations(:tokyo).id.to_s, cookies[:current_location_id]
  end

  test "update ignores an unknown location" do
    patch settings_location_url, params: { current_location_id: 999_999 }

    assert_redirected_to settings_path
    assert_predicate cookies[:current_location_id], :blank?
  end
end
