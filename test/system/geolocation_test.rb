require "application_system_test_case"

class GeolocationTest < ApplicationSystemTestCase
  # Both paths stub navigator.geolocation rather than letting the browser
  # decide. Chrome only refuses outright on an insecure origin, and whether the
  # test server is one depends on how the suite is driven: `served_by
  # host: "rails-app"` isn't, while Capybara's own default of 127.0.0.1 is a
  # secure context, where headless Chrome runs the real permission flow and may
  # deny, hang, or resolve. Deciding the outcome here keeps the test about our
  # code, and is the only way to exercise the happy path end to end at all.
  test "locating drops you on your nearest location's settings" do
    visit settings_location_path
    assert_selector ".picker__row--locate", text: "Use My Current Location"

    locate_at(latitude: 35.0, longitude: 139.0) # near the Tokyo fixture

    assert_selector ".settings__header", text: "Change Settings"
    assert_selector ".settings__value", text: locations(:tokyo).name
  end

  test "the picker says so when the browser won't locate, and stays put" do
    visit settings_location_path

    refuse_to_locate

    assert_selector ".picker__notice", text: /couldn't get your location/
    assert_selector ".picker__row", text: locations(:berlin).country # still pickable by hand
  end

  test "the geolocation row is offered only when choosing a country" do
    visit settings_location_path(country: locations(:berlin).country)

    assert_no_selector ".picker__row--locate"
  end

  private

  def locate_at(latitude:, longitude:)
    stub_geolocation("(ok) => ok({ coords: { latitude: #{latitude}, longitude: #{longitude} } })")
    click_button "Use My Current Location"
  end

  # Code 1 is PERMISSION_DENIED, what Chrome answers on an insecure origin.
  def refuse_to_locate
    stub_geolocation("(_ok, fail) => fail({ code: 1 })")
    click_button "Use My Current Location"
  end

  def stub_geolocation(callback)
    execute_script("navigator.geolocation.getCurrentPosition = #{callback}")
  end
end
