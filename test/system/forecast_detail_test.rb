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

    # ▲ walks up through the index panels to UV; a further ▲ is a no-op (top).
    %w[laundry air_quality uv].each do |panel|
      find("body").send_keys(:up)
      assert_selector ".wii[data-active-panel=#{panel}]"
    end
    find("body").send_keys(:up)
    assert_selector ".wii[data-active-panel=uv]"

    # ▼ walks back down through the whole stack to the last panel, then stops.
    %w[air_quality laundry current today tomorrow five_day].each do |panel|
      find("body").send_keys(:down)
      assert_selector ".wii[data-active-panel=#{panel}]"
    end
    find("body").send_keys(:down)
    assert_selector ".wii[data-active-panel=five_day]"
  end

  test "reaches the detail view from the locations list" do
    sign_in_as(users(:one)) # the locations list is admin-only
    visit locations_path
    click_link "Testville"
    assert_selector ".wii-header__title", text: "CURRENT" # css uppercases the title
    assert_selector ".wii-header__location", text: "Testville"
  end

  test "the Today panel reveals the 6-hour breakdown and restores on close" do
    location = Location.create!(
      name: "Overlaytown", latitude: 35, longitude: -78, timezone: "UTC",
      weather_refreshed_at: Time.utc(2026, 7, 16, 12),
      today_forecast: { "date" => "2026-07-16", "high" => 20, "condition_code" => 2 },
      hourly_windows: [ { "day" => "today", "window" => "morning", "condition_code" => 2 } ]
    )
    visit location_path(location)
    assert_selector ".wii[data-active-panel=current]", wait: 10

    find("body").send_keys(:down)
    assert_selector ".wii[data-active-panel=today]"

    find(".wii-panel-body[data-panel=today] .wii-sixhour-zone").click
    assert_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "THURSDAY" # shared title swaps to the weekday
    assert_selector ".wii-sixhour__heading", text: "6-Hour Weather"

    find("body").send_keys(:escape)
    assert_no_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "TODAY" # restored
  end
end
