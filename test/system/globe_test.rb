require "application_system_test_case"

class GlobeTest < ApplicationSystemTestCase
  test "plots a weather marker for each location on the globe" do
    visit root_path

    # Mapbox renders each marker element with the .mapboxgl-marker class. We
    # count with visible: :all because markers on the far side of the globe are
    # occluded (hidden) by design.
    assert_selector ".mapboxgl-marker", count: Location.count, visible: :all, wait: 10
    assert_selector ".weather-marker__icon svg", minimum: 1, visible: :all
  end
end
