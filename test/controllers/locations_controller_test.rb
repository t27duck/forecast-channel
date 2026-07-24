require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:berlin)
    sign_in_as(users(:one)) # managing locations is admin-only
  end

  test "forecast pages stay public when signed out" do
    sign_out

    get root_url
    assert_response :success

    get location_url(@location)
    assert_response :success
  end

  test "managing locations requires signing in" do
    sign_out

    get locations_url
    assert_redirected_to new_session_path

    get new_location_url
    assert_redirected_to new_session_path

    assert_no_difference("Location.count") do
      post locations_url, params: { location: { name: "Oslo", latitude: 59.91, longitude: 10.75 } }
    end
    assert_redirected_to new_session_path
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

  test "show renders the five forecast panels without the app nav" do
    get location_url(@location)
    assert_response :success
    assert_select "nav", false, "detail view should hide the app nav"
    assert_select "[data-controller~=forecast]"
    assert_select "[data-panel]", 7
    assert_select ".wii-header__location", text: @location.name
  end

  test "the current location plays the current track and links Globe to it" do
    write_signed_cookie(:current_location_id, locations(:berlin).id)
    get location_url(locations(:berlin))
    assert_select "body[data-music-zone=?]", "current"
    assert_select ".wii-bottom a[href=?]", map_path(location: locations(:berlin).slug), text: "Globe"
  end

  test "another location plays the forecast track and returns Globe to the saved view" do
    write_signed_cookie(:current_location_id, locations(:berlin).id)
    get location_url(locations(:tokyo))
    assert_select "body[data-music-zone=?]", "current"
    assert_select ".wii-bottom a[href=?]", map_path, text: "Globe"
  end

  test "the jukebox points at the uploaded tracks, and is blank without them" do
    get location_url(@location)
    assert_select "#jukebox[data-jukebox-current-day-value=?]", ""

    sound = Sound.create!(kind: "current_day",
      audio: fixture_file_upload("track.mp3", "audio/mpeg"))

    get location_url(@location)
    assert_select "#jukebox[data-jukebox-current-day-value=?]",
      Rails.application.routes.url_helpers.rails_storage_proxy_path(sound.audio, only_path: true)
  end

  test "viewing a forecast marks the location as recently viewed" do
    assert_nil locations(:tokyo).last_viewed_at

    get location_url(locations(:tokyo))

    assert_not_nil locations(:tokyo).reload.last_viewed_at
    assert_includes Location.hot, locations(:tokyo) # keeps it in the hourly tier
  end

  test "root shows the first location's forecast by default" do
    get root_url
    assert_response :success
    assert_select "[data-controller~=forecast]"
    assert_select ".wii-header__location", text: Location.by_name.first.name
    assert_select "body[data-music-zone=?]", "current" # forecast music, not globe
  end

  test "root auto-locates only when no location cookie is set" do
    get root_url
    assert_select "[data-controller=geolocate]", true, "should ask the browser to locate on first visit"

    write_signed_cookie(:current_location_id, locations(:tokyo).id)
    get root_url
    assert_select "[data-controller=geolocate]", false, "should not auto-locate once a location is chosen"
  end

  test "an unsigned location cookie from an older version is ignored" do
    cookies[:current_location_id] = locations(:tokyo).id # plaintext, as the app once wrote

    get root_url
    assert_select ".wii-header__location", text: Location.by_name.first.name
    assert_select "[data-controller=geolocate]", true, "an unverifiable cookie counts as unset"
  end

  test "root redirects to add a location when none exist" do
    Location.delete_all
    get root_url
    assert_redirected_to new_location_path
  end

  test "index links each location to its detail view" do
    get locations_url
    assert_select "a[href=?]", location_path(@location), text: @location.name
    assert_select "a[href=?]", "/locations/#{@location.slug}", text: @location.name
  end

  test "show is addressed by slug alone — an id or an unknown slug is a 404" do
    get "/locations/#{@location.id}"
    assert_response :not_found

    get "/locations/nowhere-at-all"
    assert_response :not_found
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

  test "refresh updates a location's weather" do
    payload = open_meteo_forecast_payload
    stub_air_quality do
      stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { payload }) do
        post refresh_location_url(@location)
      end
    end

    assert_redirected_to locations_url
    assert_not_nil @location.reload.weather_refreshed_at
  end

  test "refresh reports when the weather service is unreachable" do
    stub_singleton(OpenMeteo::ForecastClient, :fetch, ->(**) { nil }) do
      post refresh_location_url(@location)
    end

    assert_redirected_to locations_url
    assert_equal "Couldn't reach the weather service for #{@location.name}.", flash[:alert]
  end

  test "refresh_all enqueues the bulk refresh job" do
    assert_enqueued_with(job: RefreshAllWeatherJob) do
      post refresh_all_locations_url
    end
    assert_redirected_to locations_url
  end
end
