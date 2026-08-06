require "application_system_test_case"

# The panels are driven by the ▲/▼ bar buttons and the arrow keys, neither of
# which a phone has. These cover the third way in: a finger.
class ForecastSwipeTest < ApplicationSystemTestCase
  setup do
    choose_location(locations(:berlin)) # forecasts are gated on having one
    @location = Location.create!(
      name: "Swipeville", latitude: 35, longitude: -78, timezone: "UTC",
      current_temperature: 20, current_condition_code: 2,
      weather_refreshed_at: Time.utc(2026, 7, 16, 12),
      today_forecast: { "date" => "2026-07-16", "high" => 20, "condition_code" => 2 },
      tomorrow_forecast: { "date" => "2026-07-17", "high" => 22, "condition_code" => 2 },
      hourly_windows: [
        { "day" => "today", "window" => "morning", "condition_code" => 2 },
        { "day" => "tomorrow", "window" => "morning", "condition_code" => 2 }
      ]
    )
    visit location_path(@location)
    assert_selector ".wii[data-active-panel=current]", wait: 10
  end

  # Dragging up pulls the track up, which brings the panel below into view —
  # the gesture matches the transform rather than the words "next"/"previous".
  test "swiping walks the panel stack in the direction of the drag" do
    swipe(".wii-viewport", by: -160)
    assert_selector ".wii[data-active-panel=today]"
    assert_selector ".wii-header__title", text: "TODAY"

    swipe(".wii-viewport", by: -160)
    assert_selector ".wii[data-active-panel=tomorrow]"

    swipe(".wii-viewport", by: 160)
    assert_selector ".wii[data-active-panel=today]"
  end

  test "a drag too short to be a swipe leaves the panels alone" do
    swipe(".wii-viewport", by: -20)
    assert_selector ".wii[data-active-panel=current]"
  end

  test "a mostly-horizontal drag doesn't move the panels" do
    swipe(".wii-viewport", by: -160, axis: :horizontal)
    assert_selector ".wii[data-active-panel=current]"
  end

  # Touch and pen only: on a desktop the same drag is as likely to be a slip as
  # an instruction, and the ▲/▼ buttons and arrow keys are already there.
  test "a mouse drag doesn't move the panels" do
    viewport = find(".wii-viewport").native
    page.driver.browser.action
      .move_to(viewport, 0, 80)
      .click_and_hold
      .move_to(viewport, 0, -80)
      .release
      .perform

    assert_selector ".wii[data-active-panel=current]"
  end

  # A finger drag still ends in a click, and the Today panel's whole body opens
  # the 6-hour overlay when clicked — so without the controller swallowing it,
  # every swipe across Today would leave the overlay up on the way past.
  test "swiping across the Today panel doesn't open the 6-hour breakdown" do
    swipe(".wii-viewport", by: -160)
    assert_selector ".wii[data-active-panel=today]"

    swipe(".wii-panel-body[data-panel=today] .wii-sixhour-zone", by: -160)

    assert_selector ".wii[data-active-panel=tomorrow]"
    assert_no_selector ".wii-sixhour-zone.is-open"
  end

  # The other side of that suppression: it must not outlive the swipe.
  test "tapping the Today panel still opens the 6-hour breakdown" do
    swipe(".wii-viewport", by: -160)
    assert_selector ".wii[data-active-panel=today]"

    find(".wii-panel-body[data-panel=today] .wii-sixhour-zone").click

    assert_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "THURSDAY"
  end

  # Same rule as the buttons and the arrow keys — see the forecast controller's
  # #dismissOverlay, and forecast_detail_test.rb for the keyboard version.
  test "swiping with the 6-hour breakdown open closes it instead of moving" do
    swipe(".wii-viewport", by: -160)
    find(".wii-panel-body[data-panel=today] .wii-sixhour-zone").click
    assert_selector ".wii-sixhour-zone.is-open"

    swipe(".wii-panel-body[data-panel=today] .wii-sixhour-zone", by: -160)

    assert_no_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii[data-active-panel=today]"
    assert_selector ".wii-header__title", text: "TODAY"
  end
end
