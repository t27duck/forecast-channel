require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root leads to the visitor's own location" do
    write_signed_cookie(:current_location_id, locations(:tokyo).id)

    get root_url
    assert_redirected_to location_path(locations(:tokyo))
  end

  test "root sends a first-time visitor to the location picker" do
    get root_url
    assert_redirected_to settings_location_path
  end

  test "an unsigned location cookie from an older version counts as unset" do
    cookies[:current_location_id] = locations(:tokyo).id # plaintext, as the app once wrote

    get root_url
    assert_redirected_to settings_location_path
  end

  test "a location cookie pointing at a deleted location counts as unset" do
    write_signed_cookie(:current_location_id, locations(:tokyo).id)
    locations(:tokyo).destroy

    get root_url
    assert_redirected_to settings_location_path
  end
end
