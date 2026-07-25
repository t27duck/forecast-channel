require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  test "first-time setup: the picker comes first, then the settings screen" do
    # No location chosen yet, so every visitor screen leads to the picker.
    visit settings_path
    assert_selector ".picker__prompt", text: "country"
    assert_no_link "Back" # nowhere to go back to before a location exists

    click_link locations(:tokyo).country # Japan
    assert_selector ".picker__prompt", text: "location"
    click_button locations(:tokyo).name  # Tokyo

    # Choosing lands on settings, and Japan leaves the units at their defaults.
    assert_selector ".settings__value", text: locations(:tokyo).name
    assert_selector ".settings__value", text: "Celsius"

    click_button "Change", match: :first # Temperature Display row
    assert_selector ".settings__value", text: "Fahrenheit"

    # Root now plays the splash and lands on the chosen location's forecast.
    visit root_path
    assert_selector ".wii-header__location", text: locations(:tokyo).name, wait: 15
  end

  test "choosing a US location switches the units to Fahrenheit and mph" do
    Location.create!(name: "Austin", country: "United States", country_code: "US",
      admin1: "Texas", latitude: 30.27, longitude: -97.74)

    choose_location(Location.find_by(name: "Austin"))

    assert_selector ".settings__value", text: "Fahrenheit"
    assert_selector ".settings__value", text: "mph"
  end
end
