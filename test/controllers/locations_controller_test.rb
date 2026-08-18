require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    @location = locations(:berlin)
    # Forecasts are gated on having chosen a closest location.
    write_signed_cookie(:current_location_id, @location.id)
    sign_in_as(users(:one)) # managing locations is admin-only
  end

  test "forecast pages stay public when signed out" do
    sign_out

    get location_url(@location)
    assert_response :success
  end

  test "a forecast is out of reach until a location has been chosen" do
    forget_cookie(:current_location_id)

    get location_url(@location)
    assert_redirected_to settings_location_path
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

  test "show renders the forecast panels without the app nav" do
    get location_url(@location)
    assert_response :success
    assert_select "nav", false, "detail view should hide the app nav"
    assert_select "[data-controller~=forecast]"
    # The seven navigable panels, plus the secret one that rides along in the
    # track (ForecastsHelper::SECRET_PANEL).
    assert_select "[data-panel]", 8
    assert_select "[data-forecast-secret]", 1
    assert_select ".wii-header__location", text: @location.name
  end

  # No JavaScript runs here, so this is exactly what the browser paints first.
  test "show renders the default panel's state, so the first paint needs no JavaScript" do
    get location_url(@location)

    assert_select ".wii[data-active-panel=?]", "current"
    assert_select ".wii__track[style=?]", "transform: translateY(-300%)"
    assert_select ".wii-header__title", text: "Current"
    assert_select "[data-forecast-target=prevLabel]", text: "UV Index"
    assert_select "[data-forecast-target=nextLabel]", text: "Today"
    assert_select ".wii-arrow[hidden]", false, "the arrows must not need JavaScript to appear"
  end

  test "the bottom bar sends people to the source, in a new tab" do
    get location_url(@location)
    assert_select ".wii-bottom a[href=?][target=_blank][rel=noopener]",
      "https://github.com/t27duck/forecast-channel", text: "GitHub"
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

  # An open globe would otherwise keep drawing the markers it fetched when it
  # opened, and only notice a city appearing or vanishing at the next sweep.
  test "adding, editing and removing a location each tell the globe" do
    assert_turbo_stream_broadcasts Location::WEATHER_STREAM, count: 1 do
      post locations_url, params: { location: {
        name: "Oslo", latitude: 59.91, longitude: 10.75, country: "Norway"
      } }
    end

    # A rename moves the marker's label *and* its slug, which is the URL the
    # globe clicks through to.
    assert_turbo_stream_broadcasts Location::WEATHER_STREAM, count: 1 do
      patch location_url(@location), params: { location: { name: "Berlin Mitte" } }
    end

    # Reload first: the rename above rebuilt the slug, so the URL this object
    # would still generate points at a location that no longer answers.
    assert_turbo_stream_broadcasts Location::WEATHER_STREAM, count: 1 do
      delete location_url(@location.reload)
    end
  end

  test "a rejected create tells the globe nothing" do
    assert_no_turbo_stream_broadcasts Location::WEATHER_STREAM do
      post locations_url, params: { location: { name: "", latitude: "", longitude: "" } }
    end
  end

  # The index shows temperatures in whichever unit this admin chose, so it can't
  # be sent markup — it re-requests the page itself.
  test "the index subscribes to its own stream and opts into morphing" do
    get locations_url

    assert_select "turbo-cable-stream-source"
    assert_select "meta[name=turbo-refresh-method][content=?]", "morph"
    assert_select "meta[name=turbo-refresh-scroll][content=?]", "preserve"
  end

  # Weather refreshes under anyone who leaves the forecast open, so it
  # re-renders itself — but the screen keeps the panel position, the header
  # title and the 6-hour overlay in JavaScript, and a morph reaching those would
  # stomp all three. The chrome opts out; the panels and the "As of" stamp don't.
  test "the forecast subscribes, morphs, and fences off the chrome" do
    get location_url(@location)

    assert_select "turbo-cable-stream-source"
    assert_select "meta[name=turbo-refresh-method][content=?]", "morph"

    assert_select ".wii-top[data-forecast-frozen]"
    assert_select ".wii-header[data-forecast-frozen]"
    assert_select ".wii-bottom[data-forecast-frozen]"
    assert_select ".wii__track[data-forecast-frozen]", false, "the panels are the point"
    assert_select ".wii-footerline[data-forecast-frozen]", false, "the As-of stamp has to move"

    # The neighbouring idea, and the wrong one: it survives *navigations*, keyed
    # by id, keeping the old copy — which would strand the previous city's name
    # in the header. Freezing a morph is all that's wanted. (The jukebox in the
    # layout is a genuine permanent element, hence scoping this to the screen.)
    assert_select ".wii [data-turbo-permanent]", false,
      "the forecast should freeze morphs, not preserve elements across visits"

    # A permanent element is matched across renders by its id, so one without an
    # id can't work — and Hotwire Dev Tools warns about it in the console. The
    # jukebox in the layout is the only one we keep, and it has an id.
    assert_select "[data-turbo-permanent]:not([id])", false,
      "a permanent element without an id is matched by nothing"
  end

  # The stats strip drops blank tiles, so two renders of a panel can differ in
  # shape; without ids the morph has to guess which sibling is which.
  test "each panel and 6-hour zone carries a stable id for the morph to match on" do
    get location_url(@location)

    ForecastsHelper::PANELS.each { |panel| assert_select "##{"panel_#{panel[:key]}"}" }
    assert_select "#sixhour_today"
    assert_select "#sixhour_tomorrow"
  end

  # Scoped per view, never in the layout: the picker and settings share the same
  # silver bars but none of the state, and the globe would rebuild all of Mapbox.
  test "morphing stays off every other screen" do
    get map_url
    assert_select "meta[name=turbo-refresh-method]", false

    get settings_url
    assert_select "meta[name=turbo-refresh-method]", false

    get root_url
    assert_select "meta[name=turbo-refresh-method]", false
  end
end
