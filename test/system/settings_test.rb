require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  test "changing the temperature unit and closest location" do
    Setting.current.celsius!

    visit settings_path
    assert_selector ".settings__value", text: "Celsius"

    click_button "Change", match: :first # Temperature Display row
    assert_selector ".settings__value", text: "Fahrenheit"
    assert_predicate Setting.current.reload, :fahrenheit?

    # Closest location is picked country-then-place.
    click_link "Change" # the Closest Location row (a link; the units are buttons)
    assert_selector ".picker__prompt", text: "country"
    click_link locations(:tokyo).country # Japan
    assert_selector ".picker__prompt", text: "location"
    click_button locations(:tokyo).name # Tokyo
    assert_selector ".settings__value", text: locations(:tokyo).name

    # Root now shows the chosen location's forecast.
    visit root_path
    assert_selector ".wii-header__location", text: locations(:tokyo).name
  end
end
