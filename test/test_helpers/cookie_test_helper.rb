# The app stores a visitor's preferences in signed cookies
# (ApplicationController#store_visitor_cookie). Rack::Test's cookie jar has no
# #signed, so tests sign and verify through a throwaway request's jar — the
# same trick sign_in_as uses for the session cookie.
module CookieTestHelper
  # Sets a cookie the way the app would, so a test can arrive with preferences
  # already stored.
  def write_signed_cookie(name, value)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[name] = value
    cookies[name.to_s] = jar[name]
  end

  # The value behind a signed cookie the app just set, or nil if it isn't one.
  def read_signed_cookie(name)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar[name] = cookies[name.to_s]
    jar.signed[name]
  end

  # Forgets a cookie, so a test can play a visitor who hasn't been here before.
  # Rack::Test's jar matches on the string name, and drops a symbol silently.
  def forget_cookie(name)
    cookies.delete(name.to_s)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include CookieTestHelper
end
