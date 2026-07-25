require "application_system_test_case"

class MuteTest < ApplicationSystemTestCase
  # A one-sample silent WAV, inlined as a data: URI. The rule against playing a
  # real track exists because streaming a multi-MB file pins one of the test
  # server's few threads for its whole duration; this makes no request at all,
  # so the jukebox gets a genuinely loadable source at no cost.
  SILENT_WAV = "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA="

  # The audio lives at module scope inside the controller, out of reach of the
  # DOM, so whether anything is actually sounding has to come from the
  # controller itself.
  JUKEBOX = %(window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("jukebox"), "jukebox"))

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

  test "the settings Sound row toggles the same preference as the mute button" do
    choose_location(locations(:berlin))

    visit settings_path
    execute_script("window.localStorage.clear()")
    visit settings_path # start from a known (unmuted) state

    row = find(".settings__row[data-controller=mute]")
    assert_equal "On", row.find(".settings__value").text

    row.click_button "Change"
    assert_equal "Off", row.find(".settings__value").text
    assert_equal "1", evaluate_script("window.localStorage.getItem('jukeboxMuted')")

    # One store, two screens: the forecast bar's button already agrees.
    visit location_path(locations(:berlin))
    assert_selector ".wii-mute.is-muted"
  end

  # Settings pauses the track rather than dropping it, so the forecast's music
  # is still loaded and one play() away the whole time you're on that screen.
  test "unmuting on the settings page doesn't resume the forecast's track" do
    choose_location(locations(:berlin))
    visit location_path(locations(:berlin))
    execute_script("window.localStorage.clear()")

    play_a_silent_track
    find("body").click # the gesture autoplay waits for
    assert_jukebox_paused false, "the forecast should be playing"

    visit settings_path
    assert_jukebox_paused true, "settings names no music zone"

    row = find(".settings__row[data-controller=mute]")
    row.click_button "Change" # off
    row.click_button "Change" # and back on
    assert_equal "On", row.find(".settings__value").text
    assert_jukebox_paused true, "unmuting must not restart what the zone paused"
  end

  private

  # Hands the jukebox a source it can actually load, in place of the uploads no
  # system test may have, and lets it pick the change up.
  def play_a_silent_track
    execute_script(<<~JS)
      const player = document.getElementById("jukebox")
      player.setAttribute("data-jukebox-current-day-value", "#{SILENT_WAV}")
      player.setAttribute("data-jukebox-current-night-value", "#{SILENT_WAV}")
      #{JUKEBOX}.refresh()
    JS
  end

  # evaluate_script doesn't retry the way Capybara's matchers do, and both
  # play() and pause() settle a beat after the click that caused them.
  def assert_jukebox_paused(expected, message)
    deadline = Time.now + 5
    paused = nil

    while Time.now < deadline
      paused = evaluate_script("#{JUKEBOX}.paused")
      break if paused == expected

      sleep 0.1
    end

    assert_equal expected, paused, message
  end
end
