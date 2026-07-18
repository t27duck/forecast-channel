require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "renders the globe with a marker payload for each location" do
    get root_url
    assert_response :success

    assert_select "[data-controller=globe]" do |elements|
      payload = JSON.parse(elements.first["data-globe-locations-value"])
      assert_equal Location.count, payload.size
      assert_includes payload.map { |l| l["name"] }, locations(:berlin).name
    end
  end

  test "marker payload carries coordinates and condition code" do
    get root_url

    payload = JSON.parse(css_select("[data-controller=globe]").first["data-globe-locations-value"])
    berlin = payload.find { |l| l["name"] == locations(:berlin).name }

    assert_in_delta locations(:berlin).latitude, berlin["latitude"]
    assert_equal locations(:berlin).current_condition_code, berlin["condition_code"]
  end
end
