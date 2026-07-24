require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
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
end
