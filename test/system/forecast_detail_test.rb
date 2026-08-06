require "application_system_test_case"

class ForecastDetailTest < ApplicationSystemTestCase
  setup do
    choose_location(locations(:berlin)) # forecasts are gated on having one
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

    # ▲ walks up through the index panels to Laundry; a further ▲ is a no-op (top).
    %w[uv air_quality laundry].each do |panel|
      find("body").send_keys(:up)
      assert_selector ".wii[data-active-panel=#{panel}]"
    end
    find("body").send_keys(:up)
    assert_selector ".wii[data-active-panel=laundry]"

    # ▼ walks back down through the whole stack to the last panel, then stops.
    %w[air_quality uv current today tomorrow five_day].each do |panel|
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

  # Moving with the overlay up used to slide it off screen still open, leaving
  # its weekday in the frozen header over a panel it had nothing to do with.
  test "the first move backs out of the 6-hour breakdown rather than carrying it along" do
    location = Location.create!(
      name: "Overlaytown", latitude: 35, longitude: -78, timezone: "UTC",
      weather_refreshed_at: Time.utc(2026, 7, 16, 12),
      today_forecast: { "date" => "2026-07-16", "high" => 20, "condition_code" => 2 },
      tomorrow_forecast: { "date" => "2026-07-17", "high" => 22, "condition_code" => 2 },
      hourly_windows: [
        { "day" => "today", "window" => "morning", "condition_code" => 2 },
        { "day" => "tomorrow", "window" => "morning", "condition_code" => 2 }
      ]
    )
    visit location_path(location)
    assert_selector ".wii[data-active-panel=current]", wait: 10

    find("body").send_keys(:down)
    find(".wii-panel-body[data-panel=today] .wii-sixhour-zone").click
    assert_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "THURSDAY"

    # Closes the overlay and stays put.
    find("body").send_keys(:down)
    assert_no_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii[data-active-panel=today]"
    assert_selector ".wii-header__title", text: "TODAY"

    # The next one moves, as usual.
    find("body").send_keys(:down)
    assert_selector ".wii[data-active-panel=tomorrow]"
    assert_selector ".wii-header__title", text: "TOMORROW"

    # Tomorrow's zone was listening for that dismiss too. It was never open, so
    # it must not have restored a title of its own over the header.
    find(".wii-panel-body[data-panel=tomorrow] .wii-sixhour-zone").click
    assert_selector ".wii-header__title", text: "FRIDAY"
    find("body").send_keys(:up)
    assert_no_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "TOMORROW"
  end

  # Weather refreshes under anyone who leaves the channel on, so the panels
  # re-render themselves. The morph has to reach the readings without disturbing
  # anything the reader is in the middle of.
  test "a refresh brings new readings in without moving the reader" do
    visit location_path(@location)
    assert_selector ".wii[data-active-panel=current]", wait: 10
    # Berlin is the chosen location, so these render in Celsius.
    assert_selector ".wii-temp", text: "20"
    assert_text "As of 3:00 p.m., 07/18"

    # Somewhere other than the panel the server renders first.
    find("body").send_keys(:down)
    find("body").send_keys(:down)
    assert_selector ".wii[data-active-panel=tomorrow]"

    # Survives a morph but not a reload, so it also proves the page wasn't
    # simply thrown away and rebuilt.
    execute_script("window.__survivedTheMorph = true")

    @location.update!(current_temperature: -5, weather_refreshed_at: Time.utc(2026, 7, 18, 21))
    broadcast_refresh

    assert_text "As of 4:00 p.m., 07/18", wait: 10 # the footer stamp is not permanent
    assert_selector ".wii[data-active-panel=tomorrow]" # still where the reader was

    # visible: :all — the reading that changed is on Current, which the viewport
    # clips while the reader sits on Tomorrow.
    assert_selector "#panel_current .wii-temp", text: "-5", visible: :all

    assert_equal true, evaluate_script("window.__survivedTheMorph"),
      "expected a morph in place, not a full page load"

    # And it's really on screen once they walk back to it.
    2.times { find("body").send_keys(:up) }
    assert_selector ".wii[data-active-panel=current]"
    assert_selector ".wii-temp", text: "-5"
  end

  test "a refresh leaves the header, the bars and the open overlay alone" do
    location = Location.create!(
      name: "Overlaytown", latitude: 35, longitude: -78, timezone: "UTC",
      weather_refreshed_at: Time.utc(2026, 7, 16, 12),
      today_forecast: { "date" => "2026-07-16", "high" => 20, "condition_code" => 2 },
      hourly_windows: [ { "day" => "today", "window" => "morning", "condition_code" => 2 } ]
    )
    visit location_path(location)
    assert_selector ".wii[data-active-panel=current]", wait: 10

    find("body").send_keys(:down)
    find(".wii-panel-body[data-panel=today] .wii-sixhour-zone").click
    assert_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "THURSDAY"

    location.update!(weather_refreshed_at: Time.utc(2026, 7, 16, 13))
    broadcast_refresh

    # The overlay's class lives on an element the morph rewrites, so the
    # controller re-asserts it; the weekday title sits in the permanent header
    # and is never touched.
    assert_selector ".wii-sixhour-zone.is-open", wait: 10
    assert_selector ".wii-header__title", text: "THURSDAY"
    assert_selector ".wii-sixhour__heading", text: "6-Hour Weather"

    # Still closes afterwards, so the re-assertion didn't pin it open.
    find("body").send_keys(:escape)
    assert_no_selector ".wii-sixhour-zone.is-open"
    assert_selector ".wii-header__title", text: "TODAY"
  end

  test "a refresh doesn't reset the mute button under the reader" do
    visit location_path(@location)
    assert_selector ".wii[data-active-panel=current]", wait: 10

    find(".wii-mute").click
    assert_selector ".wii-mute.is-muted"

    broadcast_refresh
    sleep 1

    # The bar is permanent, so the server's unmuted markup never lands on it —
    # otherwise the icon would say the music is back on while it stayed off.
    assert_selector ".wii-mute.is-muted"
    assert_equal "1", evaluate_script("localStorage.getItem('jukeboxMuted')")
  end

  # The chrome is held out of a refresh *morph* only. Reaching for
  # data-turbo-permanent instead would preserve it across navigations too, and
  # Turbo keeps the old copy — so walking from one forecast to another would
  # leave the previous city's name in the header.
  test "walking to another forecast still re-renders the frozen chrome" do
    elsewhere = Location.create!(
      name: "Otherton", latitude: 10, longitude: 20, timezone: "UTC",
      current_temperature: 5, current_condition_code: 0,
      weather_refreshed_at: Time.utc(2026, 7, 18, 20)
    )

    visit location_path(@location)
    assert_selector ".wii-header__location", text: "Testville", wait: 10

    # A Turbo visit, not a fresh browser load — that's the path that consults
    # the permanent-element map.
    execute_script("window.Turbo.visit('#{location_path(elsewhere)}')")

    assert_selector ".wii-header__location", text: "Otherton", wait: 10
    assert_no_selector ".wii-header__location", text: "Testville"
  end

  private

  # The test cable adapter records broadcasts rather than delivering them, so
  # hand the page the element the server would have sent.
  def broadcast_refresh
    execute_script(
      "window.Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')"
    )
  end
end
