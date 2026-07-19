require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "renders the globe container pointing at the markers feed" do
    get map_url
    assert_response :success
    assert_select "[data-controller=globe][data-globe-markers-url-value=?]", map_markers_path
    assert_select "[data-controller=globe] [data-globe-target=map]"
  end

  test "overlays a control bar with zoom/next buttons, a banner, and no app nav" do
    get map_url
    assert_select ".map-bar .wii-arrow", 3
    assert_select ".map-bar .wii-arrow[data-action=?]", "globe#zoomOut"
    assert_select ".map-bar .wii-arrow[data-action=?]", "globe#next"
    assert_select ".map-bar .wii-arrow[data-action=?]", "globe#zoomIn"
    assert_select ".map-banner[data-globe-target=banner]", text: "Current Weather"
    assert_select "nav a", { text: "Forecast", count: 0 } # app header removed here
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
    assert_equal locations(:berlin).id, berlin["properties"]["id"] # for globe click-through
    assert_equal "overcast", berlin["properties"]["icon"] # berlin fixture: code 3
    # No today/tomorrow forecast fetched yet -> fall back to the current icon.
    assert_equal "overcast", berlin["properties"]["icon_today"]
    assert_equal "overcast", berlin["properties"]["icon_tomorrow"]
    assert_equal locations(:berlin).population, berlin["properties"]["population"]
  end
end
