require "application_system_test_case"

class ForecastDetailTest < ApplicationSystemTestCase
  setup do
    @location = Location.create!(
      name: "Testville", latitude: 30.0, longitude: -97.0, timezone: "America/Chicago",
      current_temperature: 20, current_condition_code: 2, uv_index: 6, uv_label: "High",
      weather_refreshed_at: Time.utc(2026, 7, 18, 20)
    )
  end

  test "opens on the Current panel and slides between panels without looping" do
    visit location_path(@location)

    # Default panel is Current.
    assert_selector ".wii[data-active-panel=current]", wait: 10

    # ▲ goes up to UV; a second ▲ is a no-op (top of the stack, non-looping).
    find("body").send_keys(:up)
    assert_selector ".wii[data-active-panel=uv]"
    find("body").send_keys(:up)
    assert_selector ".wii[data-active-panel=uv]"

    # ▼ walks down through the stack to the last panel, then stops.
    %w[current today tomorrow five_day].each do |panel|
      find("body").send_keys(:down)
      assert_selector ".wii[data-active-panel=#{panel}]"
    end
    find("body").send_keys(:down)
    assert_selector ".wii[data-active-panel=five_day]"
  end

  test "reaches the detail view from the locations list" do
    visit locations_path
    click_link "Testville"
    assert_selector ".wii-header__title", text: "CURRENT" # css uppercases the title
    assert_selector ".wii-header__location", text: "Testville"
  end
end
