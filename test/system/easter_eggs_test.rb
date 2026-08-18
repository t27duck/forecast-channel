require "application_system_test_case"

# The two things you have to find: the eighth forecast panel, and what the
# Konami code does to the globe. Both remember being found, in localStorage —
# so every test here starts by clearing it, since the browser is shared for the
# whole run (ApplicationSystemTestCase pins one worker).
class EasterEggsTest < ApplicationSystemTestCase
  KONAMI = %i[arrow_up arrow_up arrow_down arrow_down arrow_left arrow_right arrow_left arrow_right].freeze

  setup { choose_location(locations(:berlin)) }

  # Both eggs stay found, and the browser is shared for the whole run — a globe
  # left flat here would open flat in every globe test that ran afterwards.
  teardown { clear_unlocks }

  test "the 5-Day panel looks like the end of the stack until the panel below it is found" do
    open_forecast

    walk_to_the_end

    assert_selector ".wii-header__title", text: "5-DAY FORECAST" # uppercased in CSS
    assert_selector "[data-forecast-target=nextControl][disabled]"
    # visible: :all — an empty label has no box, so it isn't "visible" at all,
    # which is rather the point of the assertion.
    assert_equal "", find("[data-forecast-target=nextLabel]", visible: :all).text,
      "the ▼ label must not name the panel below the end"
    assert_no_selector ".wii-credits", visible: true
  end

  test "three shoves past the end reveal the credits panel" do
    open_forecast

    walk_to_the_end
    3.times { send_keys(:arrow_down) }

    assert_selector ".wii-header__title", text: "CREDITS" # uppercased in CSS
    assert_selector ".wii[data-active-panel=credits]"
    assert_selector ".wii-credits__title", text: "Forecast Channel"
    # Reaching it puts the ▲ back to the panel it came from, and the ▼ at a
    # genuine end this time.
    assert_equal "5-Day Forecast", find("[data-forecast-target=prevLabel]").text
    assert_selector "[data-forecast-target=nextControl][disabled]"
  end

  test "one shove short of it leaves the panel where it was" do
    open_forecast

    walk_to_the_end
    2.times { send_keys(:arrow_down) }

    assert_selector ".wii[data-active-panel=five_day]"
    assert_no_selector ".wii[data-active-panel=credits]"
  end

  test "turning back abandons the attempt, so the shoves have to be consecutive" do
    open_forecast

    walk_to_the_end
    2.times { send_keys(:arrow_down) }
    send_keys(:arrow_up)   # back to Tomorrow — the count starts again
    send_keys(:arrow_down) # back to 5-Day
    send_keys(:arrow_down) # shove one of three

    assert_selector ".wii[data-active-panel=five_day]"
  end

  test "once found, the credits panel stays found" do
    open_forecast

    walk_to_the_end
    3.times { send_keys(:arrow_down) }
    assert_selector ".wii[data-active-panel=credits]"
    assert_equal "1", evaluate_script("window.localStorage.getItem('forecastCredits')")

    visit location_path(locations(:berlin))
    walk_to_the_end

    assert_equal "Credits", find("[data-forecast-target=nextLabel]").text
    assert_no_selector "[data-forecast-target=nextControl][disabled]"
  end

  test "the Konami code flattens the globe, and remembers it" do
    open_globe

    assert_equal "globe", projection
    konami

    # visible: :all so the text comes from textContent: two idle seconds fade
    # the banner to nothing, and a faded element reads as having no text at all
    # (which is also why the copy here isn't the CSS-uppercased version).
    assert_selector ".map-banner", text: "Flat Earth Mode", visible: :all
    assert_equal "mercator", projection
    assert_equal "mercator", evaluate_script("window.localStorage.getItem('globeProjection')")

    # The banner is only borrowed — it goes back to naming the marker view.
    assert_selector ".map-banner", text: "Current Weather", visible: :all, wait: 5
  end

  test "the code toggles, and a flattened globe opens flat" do
    open_globe
    konami
    assert_equal "mercator", projection

    visit map_path
    assert_selector "[data-controller~=globe][data-map-ready=true]", wait: 15
    assert_equal "mercator", projection, "an unlocked globe should open flat, not unroll"

    konami
    assert_selector ".map-banner", text: "Round Earth Restored", visible: :all
    assert_equal "globe", projection
  end

  test "a fumbled run still lands, and an ordinary keypress doesn't" do
    open_globe

    send_keys(:arrow_up) # a false start the sequence has to forgive
    konami

    assert_equal "mercator", projection
  end

  # The panel is new markup on a screen that never scrolls, so the failure mode
  # is silent clipping by overflow: hidden rather than anything an ordinary
  # assertion would notice. Everything in it is sized in vmin for this reason —
  # on a phone the height is the *larger* dimension, so vh would overflow the
  # width. The window is shared for the whole run, hence the ensure.
  test "the credits panel fits a phone" do
    open_forecast
    walk_to_the_end
    3.times { send_keys(:arrow_down) }
    assert_selector ".wii[data-active-panel=credits]"

    page.driver.browser.manage.window.resize_to(390, 844)

    overflow = evaluate_script(<<~JS)
      (() => {
        const panel = document.getElementById("panel_credits")
        const box = panel.getBoundingClientRect()
        return Array.from(panel.querySelectorAll("*")).filter((el) => {
          const rect = el.getBoundingClientRect()
          return rect.width > 0 && (rect.left < box.left - 0.5 || rect.right > box.right + 0.5)
        }).map((el) => el.className.toString() || el.tagName)
      })()
    JS

    assert_empty overflow, "expected nothing in the credits panel to spill past its edges"
  ensure
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end

  private

  # Start from "nothing has been found yet". The forecast controller reads the
  # unlock on connect, so the clear has to be followed by a fresh load.
  def open_forecast
    forecast = location_path(locations(:berlin))
    visit forecast
    clear_unlocks
    visit forecast
    assert_selector ".wii[data-active-panel=current]"
  end

  def open_globe
    visit map_path
    clear_unlocks
    visit map_path
    assert_selector "[data-controller~=globe][data-map-ready=true]", wait: 15
  end

  def clear_unlocks
    execute_script(
      "window.localStorage.removeItem('forecastCredits');" \
      "window.localStorage.removeItem('globeProjection')"
    )
  rescue StandardError
    # Teardown after a test that never got a page loaded — nothing to clear.
  end

  # Current -> Today -> Tomorrow -> 5-Day, the last panel anyone is offered.
  def walk_to_the_end
    3.times { send_keys(:arrow_down) }
    assert_selector ".wii[data-active-panel=five_day]"
  end

  # The code, ending on the two letters. Sent to the page rather than to an
  # element: the detector listens on the window.
  def konami
    KONAMI.each { |key| send_keys(key) }
    send_keys("b")
    send_keys("a")
  end

  def send_keys(key)
    page.driver.browser.action.send_keys(key).perform
  end

  def projection
    evaluate_script("document.querySelector('[data-controller~=globe]').__map.getProjection().name")
  end
end
