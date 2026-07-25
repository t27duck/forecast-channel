require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup { write_signed_cookie(:current_location_id, locations(:berlin).id) }

  test "the globe waits until a closest location has been chosen" do
    forget_cookie(:current_location_id)

    get map_url
    assert_redirected_to settings_location_path
  end

  test "renders the globe container pointing at the markers feed" do
    get map_url
    assert_response :success
    assert_select "[data-controller=globe][data-globe-markers-url-value=?]", map_markers_path
    assert_select "[data-controller=globe] [data-globe-target=map]"
  end

  test "renders no Mapbox token in the test environment" do
    get map_url
    # test_helper clears MAPBOX_TOKEN to keep the suite off api.mapbox.com; the
    # globe controller falls back to its offline style.
    assert_select "[data-controller=globe][data-globe-token-value=?]", ""
  end

  test "overlays a control bar with zoom/next buttons, a banner, and no app nav" do
    get map_url
    assert_select ".map-bar--top .wii-arrow", 3
    assert_select ".map-bar--top .wii-arrow[data-action=?]", "globe#zoomOut"
    assert_select ".map-bar--top .wii-arrow[data-action=?]", "globe#next"
    assert_select ".map-bar--top .wii-arrow[data-action=?]", "globe#zoomIn"
    assert_select ".map-banner[data-globe-target=banner]", text: "Current Weather"
    assert_select "nav a", { text: "Forecast", count: 0 } # app header removed here
  end

  test "overlays a bottom bar with End, tilt, and Restore controls" do
    get map_url
    assert_select ".map-bar--bottom a.wii-chrome-link[href=?]", root_path, text: "End"
    assert_select ".map-bar--bottom .wii-arrow[data-action=?]", "globe#pitchUp"
    assert_select ".map-bar--bottom .wii-arrow[data-action=?]", "globe#pitchDown"
    assert_select ".map-bar--bottom [data-action=?]", "globe#resetPitch", text: "Restore"
  end

  test "centres the globe on the location passed from its forecast" do
    get map_url(location: locations(:berlin).slug)
    expected = [ locations(:berlin).longitude.to_f, locations(:berlin).latitude.to_f ].to_json
    assert_select "[data-controller=globe][data-globe-center-value=?]", expected
  end

  test "omits the centre value when no location is given" do
    get map_url
    assert_select "[data-globe-center-value]", false
  end

  # Mapbox rides in its own bundle, which only this page pulls in.
  test "the globe page loads the globe bundle on top of the main one" do
    get map_url
    assert_select "script[src*=?]", "/assets/globe", 1
    assert_select "script[src*=?]", "/assets/application", 1
  end

  test "a forecast page loads the main bundle only" do
    get location_url(locations(:berlin))
    assert_select "script[src*=?]", "/assets/application", 1
    assert_select "script[src*=?]", "/assets/globe", false,
      "the forecast view must not pay for Mapbox"
  end

  test "the globe selects the globe music zone" do
    get map_url
    assert_select "body[data-music-zone=?]", "globe"
    assert_select "#jukebox[data-controller=jukebox]"
  end

  test "markers feed returns a GeoJSON feature per location" do
    get map_markers_url
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "FeatureCollection", json["type"]
    assert_equal Location.count, json["features"].size

    berlin = json["features"].find { |f| f.dig("properties", "name") == locations(:berlin).name }
    assert_equal [ locations(:berlin).longitude.to_f, locations(:berlin).latitude.to_f ],
      berlin["geometry"]["coordinates"]
    assert_equal locations(:berlin).slug, berlin["properties"]["slug"] # for globe click-through
    assert_equal "overcast", berlin["properties"]["icon"] # berlin fixture: code 3
    # No today/tomorrow forecast fetched yet -> fall back to the current icon.
    assert_equal "overcast", berlin["properties"]["icon_today"]
    assert_equal "overcast", berlin["properties"]["icon_tomorrow"]
    assert_equal locations(:berlin).population, berlin["properties"]["population"]
  end
end
