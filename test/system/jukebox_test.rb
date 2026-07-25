require "application_system_test_case"

class JukeboxTest < ApplicationSystemTestCase
  setup { choose_location(locations(:berlin)) }

  test "the music zone follows navigation and the player persists" do
    visit location_path(locations(:berlin)) # the forecast itself, not via the splash
    assert_selector "#jukebox[data-controller=jukebox]", visible: :all
    assert_equal "current", evaluate_script("document.body.dataset.musicZone")

    # Mark the permanent player so we can tell if it survives navigation.
    execute_script("document.getElementById('jukebox').dataset.marked = 'yes'")
    generation = evaluate_script("document.getElementById('jukebox').dataset.generation")

    # Forecast → globe switches the zone...
    click_link "Globe"
    assert_selector "[data-controller=globe]", wait: 10
    assert_equal "globe", evaluate_script("document.body.dataset.musicZone")

    # ...and the data-turbo-permanent player is the same element (not recreated),
    # reusing the same Audio (generation unchanged) so playback never restarts.
    assert_equal "yes", evaluate_script("document.getElementById('jukebox').dataset.marked || ''")
    assert_equal generation, evaluate_script("document.getElementById('jukebox').dataset.generation")
  end

  test "leaving the map for a location switches zone without reloading the player" do
    visit map_path
    assert_selector "[data-controller=globe]", wait: 10
    assert_equal "globe", evaluate_script("document.body.dataset.musicZone")
    execute_script("document.getElementById('jukebox').dataset.marked = 'yes'")
    generation = evaluate_script("document.getElementById('jukebox').dataset.generation")

    # A marker opens another location's forecast; globe_controller navigates via
    # Turbo (not a full reload), so the permanent player is carried over.
    execute_script("window.Turbo.visit('#{location_path(locations(:tokyo))}')")
    assert_selector ".wii-header__location", text: "Tokyo"

    # Every forecast page is the "current" zone, so the source switches to the
    # forecast track — but the element and its Audio persist (same generation),
    # proving Turbo carried the player over rather than a full reload.
    assert_equal "current", evaluate_script("document.body.dataset.musicZone")
    assert_equal "yes", evaluate_script("document.getElementById('jukebox').dataset.marked || ''")
    assert_equal generation, evaluate_script("document.getElementById('jukebox').dataset.generation")
  end
end
