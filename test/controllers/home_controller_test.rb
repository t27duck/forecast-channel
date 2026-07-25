require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root plays the splash and points it at the visitor's own location" do
    write_signed_cookie(:current_location_id, locations(:tokyo).id)

    get root_url

    assert_response :success
    assert_select ".splash[data-splash-url-value=?]", location_path(locations(:tokyo))
    assert_select ".splash__message", text: "One moment, please…"
    assert_select ".splash__sun", 6
    assert_select "nav", false, "the splash should hide the app nav"
  end

  test "the splash waits for a refresh only when the weather is stale" do
    write_signed_cookie(:current_location_id, locations(:berlin).id) # refreshed 30 minutes ago
    get root_url
    assert_select ".splash[data-splash-refresh-value=?]", "false"

    locations(:berlin).update!(weather_refreshed_at: 2.hours.ago)
    get root_url
    assert_select ".splash[data-splash-refresh-value=?]", "true"
  end

  test "root as JSON refreshes weather that has gone stale" do
    locations(:berlin).update!(weather_refreshed_at: 2.hours.ago)
    write_signed_cookie(:current_location_id, locations(:berlin).id)

    payload = open_meteo_forecast_payload
    stub_air_quality do
      stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
        get root_url(format: :json)
      end
    end

    assert_response :success
    assert JSON.parse(response.body)["refreshed"]
    assert_operator locations(:berlin).reload.weather_refreshed_at, :>, 1.minute.ago
  end

  test "root as JSON leaves fresh weather alone, reaching nothing on the network" do
    write_signed_cookie(:current_location_id, locations(:berlin).id)
    before = locations(:berlin).weather_refreshed_at

    # No client stub: touching Open-Meteo here would raise rather than hang.
    get root_url(format: :json)

    assert_response :success
    assert_not JSON.parse(response.body)["refreshed"]
    assert_equal before.to_i, locations(:berlin).reload.weather_refreshed_at.to_i
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
