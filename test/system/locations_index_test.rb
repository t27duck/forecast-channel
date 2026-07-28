require "application_system_test_case"

# "Refresh all" hands the work to background jobs and leaves only an optimistic
# flash behind, so the index watches its rows land instead.
class LocationsIndexTest < ApplicationSystemTestCase
  setup { sign_in_as(users(:one)) } # managing locations is admin-only

  test "a refresh broadcast morphs new readings in without reloading the page" do
    locations(:berlin).update!(current_temperature: 4, current_condition_label: "Sleet")

    visit locations_path
    assert_selector "turbo-cable-stream-source", visible: :all
    assert_text "Sleet"

    # Survives a morph but not a reload, so it also proves the page wasn't
    # simply thrown away and rebuilt.
    execute_script("window.__survivedTheMorph = true")

    locations(:berlin).update!(current_temperature: 26, current_condition_label: "Blazing")
    broadcast_refresh

    assert_text "Blazing", wait: 10
    assert_no_text "Sleet"
    assert_equal true, evaluate_script("window.__survivedTheMorph"),
      "expected a morph in place, not a full page load"
  end

  test "the morph keeps the reader where they were on the page" do
    # The fixtures alone don't fill the viewport, so there'd be nothing to
    # scroll and nothing to prove.
    40.times do |i|
      Location.create!(name: "Scrollville #{i}", latitude: 10 + (i * 0.1), longitude: 20, timezone: "UTC")
    end

    visit locations_path
    assert_selector "turbo-cable-stream-source", visible: :all

    execute_script("window.scrollTo(0, 400)")
    assert_equal true, wait_until { evaluate_script("window.scrollY") > 0 },
      "expected the page to be long enough to scroll"

    broadcast_refresh

    # turbo-refresh-scroll: preserve — a refresh arriving mid-scroll shouldn't
    # throw the page back to the top.
    sleep 1
    assert_operator evaluate_script("window.scrollY"), :>, 0
  end

  private

  # The test cable adapter records broadcasts rather than delivering them, so
  # hand the page the element the server would have sent.
  def broadcast_refresh
    execute_script(
      "window.Turbo.renderStreamMessage('<turbo-stream action=\"refresh\"></turbo-stream>')"
    )
  end

  def wait_until(seconds: Capybara.default_max_wait_time)
    Timeout.timeout(seconds) do
      loop do
        result = yield
        return result if result

        sleep 0.1
      end
    end
  rescue Timeout::Error
    false
  end
end
