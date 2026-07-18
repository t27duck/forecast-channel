require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:berlin)
  end

  test "index lists locations" do
    get locations_url
    assert_response :success
    assert_select "h1", "Locations"
  end

  test "new renders a blank form" do
    get new_location_url
    assert_response :success
  end

  test "new prefills the form from picked search params" do
    get new_location_url(location: { name: "Paris", latitude: "48.85", longitude: "2.35" })
    assert_response :success
    assert_select "input[name=?][value=?]", "location[name]", "Paris"
  end

  test "create adds a location" do
    assert_difference("Location.count", 1) do
      post locations_url, params: { location: {
        name: "Oslo", latitude: 59.91, longitude: 10.75, country: "Norway"
      } }
    end
    assert_redirected_to locations_url
  end

  test "create with invalid data re-renders the form" do
    assert_no_difference("Location.count") do
      post locations_url, params: { location: { name: "", latitude: "", longitude: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update edits a location" do
    patch location_url(@location), params: { location: { name: "Berlin Mitte" } }
    assert_redirected_to locations_url
    assert_equal "Berlin Mitte", @location.reload.name
  end

  test "destroy removes a location" do
    assert_difference("Location.count", -1) do
      delete location_url(@location)
    end
    assert_redirected_to locations_url
  end

  test "search renders geocoding results without hitting the network" do
    results = [ OpenMeteo::GeocodingClient::Result.new(
      open_meteo_id: 1, name: "Berlin", latitude: 52.52, longitude: 13.41,
      country: "Germany", admin1: "Berlin"
    ) ]

    stub_singleton(OpenMeteo::GeocodingClient, :search, ->(*, **) { results }) do
      get search_locations_url(query: "Berlin")
    end

    assert_response :success
    assert_select "turbo-frame#location_search_results"
    assert_select "a", text: /Berlin/
  end

  test "search reports when there are no matches" do
    stub_singleton(OpenMeteo::GeocodingClient, :search, ->(*, **) { [] }) do
      get search_locations_url(query: "zzzzzz")
    end

    assert_response :success
    assert_select "p", /No matches/
  end
end
