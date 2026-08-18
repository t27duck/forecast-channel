require "application_system_test_case"

class SplashTest < ApplicationSystemTestCase
  setup { choose_location(locations(:berlin)) }

  test "the loading screen plays and hands over to the forecast" do
    visit root_path

    # Not the copy: the message changes at New Year (SeasonalTheme), and which
    # words each occasion gets is pinned in home_controller_test.
    assert_selector ".splash__message"
    assert_selector ".splash__sun", count: 6

    assert_selector ".wii-header__location", text: locations(:berlin).name, wait: 15
  end

  test "a click skips straight through" do
    visit root_path

    find(".splash__message").click

    assert_selector ".wii-header__location", text: locations(:berlin).name, wait: 5
  end

  # The refresh runs in a job now, so the screen has to be told when it's done
  # rather than guessing. These two together pin that down: it genuinely waits,
  # and the signal is what releases it.
  test "the splash holds while a refresh it queued is still running" do
    locations(:berlin).update!(weather_refreshed_at: 2.hours.ago)

    visit root_path
    assert_selector "turbo-cable-stream-source", visible: :all # listening before it asks

    # Well past MIN_MS and well short of MAX_MS: nothing but the pending
    # refresh can still be holding the screen. The job is only enqueued in the
    # test environment, so no signal is coming.
    sleep 3
    assert_selector ".splash__message"
    assert_no_selector ".wii-header__location"
  end

  test "the splash hands over as soon as the refresh lands" do
    locations(:berlin).update!(weather_refreshed_at: 2.hours.ago)

    visit root_path
    assert_selector "turbo-cable-stream-source", visible: :all

    # Standing in for the broadcast RefreshLocationWeatherJob makes; the test
    # cable adapter records broadcasts rather than delivering them.
    execute_script(
      "window.Turbo.renderStreamMessage(" \
      "'<turbo-stream action=\"weather_ready\" slug=\"#{locations(:berlin).slug}\"></turbo-stream>')"
    )

    assert_selector ".wii-header__location", text: locations(:berlin).name, wait: 4
  end

  test "the splash doesn't sit in history, so Back reaches what came before it" do
    visit settings_path
    visit root_path
    assert_selector ".wii-header__location", wait: 15

    page.go_back

    assert_selector ".settings__header", text: "Change Settings"
  end
end

# Its own class so no location is chosen first: this is what a first-time
# visitor, or a shared link, actually arrives at.
class SplashWithoutALocationTest < ApplicationSystemTestCase
  test "the loading screen plays and hands over to the picker" do
    visit root_path

    assert_selector ".splash__message"
    assert_selector ".picker__prompt", text: "Choose the country closest to where you live.", wait: 15
  end
end
