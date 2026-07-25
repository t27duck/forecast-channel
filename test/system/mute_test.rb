require "application_system_test_case"

class MuteTest < ApplicationSystemTestCase
  test "the mute button toggles and remembers the muted state" do
    choose_location(locations(:berlin))

    forecast = location_path(locations(:berlin))
    visit forecast
    execute_script("window.localStorage.clear()")
    visit forecast # start from a known (unmuted) state

    assert_no_selector ".wii-mute.is-muted"

    find(".wii-mute").click
    assert_selector ".wii-mute.is-muted"
    assert_equal "1", evaluate_script("window.localStorage.getItem('jukeboxMuted')")

    find(".wii-mute").click
    assert_no_selector ".wii-mute.is-muted"
    assert_equal "0", evaluate_script("window.localStorage.getItem('jukeboxMuted')")
  end
end
