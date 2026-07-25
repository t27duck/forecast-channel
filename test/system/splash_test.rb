require "application_system_test_case"

class SplashTest < ApplicationSystemTestCase
  setup { choose_location(locations(:berlin)) }

  test "the loading screen plays and hands over to the forecast" do
    visit root_path

    assert_selector ".splash__message", text: "One moment, please…"
    assert_selector ".splash__sun", count: 6

    assert_selector ".wii-header__location", text: locations(:berlin).name, wait: 15
  end

  test "a click skips straight through" do
    visit root_path

    find(".splash__message").click

    assert_selector ".wii-header__location", text: locations(:berlin).name, wait: 5
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

    assert_selector ".splash__message", text: "One moment, please…"
    assert_selector ".picker__prompt", text: "Choose the country closest to where you live.", wait: 15
  end
end
