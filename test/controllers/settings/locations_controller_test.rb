require "test_helper"

class Settings::LocationsControllerTest < ActionDispatch::IntegrationTest
  test "show lists the distinct countries" do
    get settings_location_url
    assert_response :success
    assert_select ".picker__prompt", /country/
    assert_select ".picker__row", text: locations(:berlin).country # Germany
    assert_select ".picker__row", text: locations(:tokyo).country  # Japan
  end

  test "show lists the locations in a chosen country with few locations" do
    get settings_location_url(country: locations(:berlin).country)
    assert_response :success
    assert_select ".picker__prompt", /location/
    assert_select ".picker__row", text: locations(:berlin).name
    assert_select ".picker__row", { count: 0, text: locations(:tokyo).name }
  end

  test "a country with many locations shows a state/region step first" do
    seed_us_cities

    get settings_location_url(country: "United States")

    assert_response :success
    assert_select ".picker__prompt", /state/
    assert_select ".picker__row", text: "California"
    assert_select ".picker__row", text: "Texas"
    assert_select ".picker__row", { count: 0, text: "Los Angeles" } # cities not shown yet
  end

  test "choosing a state lists only that state's cities" do
    seed_us_cities

    get settings_location_url(country: "United States", state: "California")

    assert_response :success
    assert_select ".picker__prompt", /location/
    assert_select ".picker__row", text: "Los Angeles"
    assert_select ".picker__row", { count: 0, text: "Houston" } # a Texas city
  end

  private

  # Enough US cities across two states to cross the state-step threshold.
  def seed_us_cities
    {
      "California" => %w[Los\ Angeles San\ Diego San\ Jose Fresno Sacramento Oakland Anaheim Irvine],
      "Texas" => %w[Houston Dallas Austin San\ Antonio Arlington Plano Laredo Lubbock]
    }.each do |state, cities|
      cities.each_with_index do |name, i|
        Location.create!(name: name, country: "United States", admin1: state,
          latitude: 30 + i * 0.2, longitude: -100 - i * 0.2)
      end
    end
  end

  test "update stores the closest location in a cookie and returns to settings" do
    patch settings_location_url, params: { current_location_id: locations(:tokyo).id }

    assert_redirected_to settings_path
    assert_equal locations(:tokyo).id, read_signed_cookie(:current_location_id)
  end

  test "update ignores an unknown location" do
    patch settings_location_url, params: { current_location_id: 999_999 }

    assert_redirected_to settings_path
    assert_nil read_signed_cookie(:current_location_id)
  end
end
