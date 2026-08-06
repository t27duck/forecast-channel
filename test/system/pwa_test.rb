require "application_system_test_case"

class PwaTest < ApplicationSystemTestCase
  # app/javascript/lib/pwa.js skips registration under a driver, and this is
  # what would go wrong without it: the worker claims the origin, caches "/" and
  # the forecasts, and a later test gets served an earlier one's HTML from a
  # cache that knows nothing about the database being rolled back in between.
  # That wouldn't fail here — it would fail somewhere else, intermittently, and
  # look like a Turbo morph bug. Hence a test with nothing else to do.
  test "no service worker registers under the test driver" do
    visit root_path
    assert_selector ".splash", wait: 10

    registrations = evaluate_async_script(<<~JS)
      const done = arguments[0]
      if (!navigator.serviceWorker) return done(0)
      navigator.serviceWorker.getRegistrations().then((all) => done(all.length))
    JS

    assert_equal 0, registrations
  end
end
