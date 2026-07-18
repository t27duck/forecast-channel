require "application_system_test_case"

class JukeboxTest < ApplicationSystemTestCase
  test "the music zone follows navigation and the player persists" do
    visit root_path
    assert_selector "#jukebox[data-controller=jukebox]", visible: :all
    assert_equal "current", evaluate_script("document.body.dataset.musicZone")

    # Mark the permanent player so we can tell if it survives navigation.
    execute_script("document.getElementById('jukebox').dataset.marked = 'yes'")

    # Forecast → globe switches the zone...
    click_link "Globe"
    assert_selector "[data-controller=globe]", wait: 10
    assert_equal "globe", evaluate_script("document.body.dataset.musicZone")

    # ...and the data-turbo-permanent player is the same element (not recreated).
    assert_equal "yes", evaluate_script("document.getElementById('jukebox').dataset.marked || ''")
  end
end
