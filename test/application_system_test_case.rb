require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # One browser at a time. Rails only parallelizes past 50 tests, so this was
  # already how the suite ran — but it was true by accident, and the run that
  # crossed the threshold turned every test into
  # "Could not start a new session. No nodes support the capabilities in the
  # request": the development Selenium container is a single node, and twelve
  # processes all asking it for a browser at once is more than it serves.
  parallelize workers: 1

  if ENV["CAPYBARA_SERVER_PORT"]
    served_by host: "rails-app", port: ENV["CAPYBARA_SERVER_PORT"]

    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ], options: {
      browser: :remote,
      url: "http://#{ENV["SELENIUM_HOST"]}:4444"
    }
  else
    # Locally and in CI, Chrome runs headless with no GPU. Mapbox needs a WebGL
    # context to build the globe at all, and recent Chrome won't fall back to
    # its software renderer without this flag.
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
      options.add_argument("--enable-unsafe-swiftshader")
    end
  end

  # System tests drive a real browser, so the integration cookie helper doesn't
  # apply — sign in through the form instead.
  def sign_in_as(user, password: "password")
    visit new_session_path
    fill_in "Username", with: user.username
    fill_in "Password", with: password
    click_on "Sign in"
    # Wait for the redirect to complete before the test navigates on, and fail
    # loudly here if the credentials were rejected (form still on screen).
    assert_no_field "Username", wait: 5
  end

  # The app holds a visitor on the picker until they've chosen their closest
  # location, so most screens need one first. The cookie is signed and
  # httponly, so a browser can only get it by going through the picker — this
  # jumps straight to the country's list of places to keep it to two loads.
  def choose_location(location)
    visit settings_location_path(country: location.country)
    click_button location.name
    assert_selector ".settings__value", text: location.name, wait: 5
  end

  # A finger drag, as a W3C Actions touch pointer, centred on +selector+ and
  # travelling +by+ pixels (negative is up / left). A real input device rather
  # than synthesised events, so the browser produces the whole
  # pointerdown/pointermove/pointerup sequence *and* the synthetic click that
  # follows it — and that click is the half the swipe controller has to
  # suppress, so faking the sequence would skip the interesting part.
  #
  # +axis+ is :vertical or :horizontal. Note the swipe controller ignores a
  # mouse pointer, so a test wanting to prove that uses `page.driver.browser
  # .action` directly rather than this.
  def swipe(selector, by:, axis: :vertical)
    finger = Selenium::WebDriver::Interactions.pointer(:touch, name: "finger")
    target = find(selector).native
    offset = ->(fraction) { axis == :vertical ? [ 0, (by * fraction).round ] : [ (by * fraction).round, 0 ] }

    # `device:` wants the name, not the device — ActionBuilder looks it up by
    # string and silently falls back to a fresh mouse pointer without one.
    page.driver.browser.action(devices: [ finger ])
      .move_to(target, *offset.call(-0.5), device: finger.name)
      .pointer_down(:left, device: finger.name)
      .move_to(target, *offset.call(0.5), device: finger.name, duration: 0.15)
      .pointer_up(:left, device: finger.name)
      .perform
  end
end
