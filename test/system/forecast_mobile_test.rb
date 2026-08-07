require "application_system_test_case"

# The panels are a fixed frame sized entirely in viewport units, so anything
# that doesn't fit is silently clipped by `overflow: hidden` rather than
# scrolling into reach — you only find out by looking. These measure instead.
#
# The bug they were written for: everything was sized in vh, which is the
# smaller dimension on a landscape desktop and the larger one on an upright
# phone, so type sized off an 844px height ran off a 390px width. See the
# stylesheet's "Sizing" note.
class ForecastMobileTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  setup do
    choose_location(locations(:berlin)) # forecasts are gated on having one
    # A long name and the longest panel titles are what actually overflowed.
    @location = Location.create!(
      name: "Wolverhampton", latitude: 39.7, longitude: -86.1, timezone: "UTC",
      current_temperature: 25.6, current_apparent_temperature: 30.0,
      current_humidity: 81, current_precipitation_probability: 7,
      current_condition_code: 3, current_condition_label: "Overcast",
      current_wind_speed: 5.0, current_wind_direction: 45,
      uv_index: 11.0, uv_label: "Extreme",
      air_quality_index: 155, air_quality_label: "Unhealthy", air_quality_pm2_5: 12.4,
      weather_refreshed_at: Time.utc(2026, 8, 6, 19, 36),
      today_forecast: {
        "date" => "2026-08-06", "high" => 26, "low" => 20, "apparent_high" => 31,
        "apparent_low" => 23, "condition_code" => 3, "condition_label" => "Overcast",
        "wind_speed" => 8, "wind_direction" => 110,
        "sunrise" => "2026-08-06T06:48", "sunset" => "2026-08-06T20:52"
      },
      tomorrow_forecast: {
        "date" => "2026-08-07", "high" => 28, "low" => 21, "apparent_high" => 33,
        "apparent_low" => 23, "condition_code" => 51, "condition_label" => "Light drizzle",
        "wind_speed" => 24, "wind_direction" => 160,
        "sunrise" => "2026-08-07T06:49", "sunset" => "2026-08-07T20:51"
      },
      five_day_forecast: (0..4).map { |day|
        { "date" => (Date.new(2026, 8, 6) + day).to_s, "high" => 26 + day, "low" => 20 + day,
          "condition_code" => 3, "condition_label" => "Overcast" }
      }
    )
  end

  # The driver's window is shared by every test in the process, so put it back.
  teardown { restore_window }

  test "nothing on any panel spills outside an upright phone" do
    resize_viewport_to(*PHONE)
    visit location_path(@location)
    assert_selector ".wii[data-active-panel=current]", wait: 10

    # Walk the whole stack from the top, so the header is measured carrying
    # each panel's title — "5-Day Forecast" is much wider than "Current".
    3.times { find("body").send_keys(:up) }
    assert_selector ".wii[data-active-panel=laundry]"

    ForecastsHelper::PANELS.each_with_index do |panel, index|
      find("body").send_keys(:down) unless index.zero?
      assert_selector ".wii[data-active-panel=#{panel[:key]}]"

      assert_empty overflowing_elements, "#{panel[:title]} spills outside the screen"
      assert_empty clipped_text, "#{panel[:title]} has text wider than the box it sits in"
    end
  end

  private

  # Elements reaching past either edge of the viewport. Only the visible panel
  # is asked about: the others are parked off-screen by the track's transform.
  def overflowing_elements
    evaluate_script(<<~JS)
      (() => {
        const width = document.documentElement.clientWidth
        const scope = ".wii-top, .wii-header, .wii-bottom, .wii-footerline, " +
          ".wii-panel-body[data-panel='" + document.querySelector(".wii").dataset.activePanel + "']"
        return [ ...document.querySelectorAll(scope) ]
          .flatMap((root) => [ root, ...root.querySelectorAll("*") ])
          .filter((el) => {
            const box = el.getBoundingClientRect()
            return box.width > 0 && (box.left < -0.5 || box.right > width + 0.5)
          })
          .map((el) => `${el.tagName.toLowerCase()}.${el.className} (${Math.round(el.getBoundingClientRect().left)}..${Math.round(el.getBoundingClientRect().right)} of ${width})`)
      })()
    JS
  end

  # Text too wide for its own box — how the index panels failed. The boxes are
  # grid tracks that can't overflow, so their readings overlapped the box next
  # to them instead and nothing left the screen at all.
  def clipped_text
    evaluate_script(<<~JS)
      (() => {
        const selector = ".wii-header__title, .wii-header__location, .wii-temp, .wii-condition, " +
          ".wii-index__value, .wii-index__label, .wii-index__heading, .wii-stat__value, .wii-day__high"
        return [ ...document.querySelectorAll(selector) ]
          .filter((el) => el.getBoundingClientRect().width > 0 && el.scrollWidth > el.clientWidth + 1)
          .map((el) => `${el.className}: ${el.scrollWidth}px of text in ${el.clientWidth}px ("${el.textContent.trim().slice(0, 20)}")`)
      })()
    JS
  end

  # Chrome sizes the *window*, and the difference is whatever toolbars it has —
  # which matters here, because a viewport shorter than asked for would quietly
  # test a smaller screen than the one in question.
  def resize_viewport_to(width, height)
    window = page.driver.browser.manage.window
    window.resize_to(width, height)
    window.resize_to(
      width + (width - evaluate_script("document.documentElement.clientWidth")),
      height + (height - evaluate_script("document.documentElement.clientHeight"))
    )
  end

  def restore_window
    page.driver.browser.manage.window.resize_to(*ApplicationSystemTestCase::SCREEN_SIZE)
  end
end
