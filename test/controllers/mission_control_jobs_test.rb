require "test_helper"

# The /jobs dashboard is Mission Control's, but the guard on it is ours: its
# controllers inherit ApplicationController, and the gem's own HTTP basic auth
# is switched off (see config/initializers/mission_control_jobs.rb).
class MissionControlJobsTest < ActionDispatch::IntegrationTest
  test "the dashboard requires signing in" do
    get mission_control_jobs.root_url

    # Spelled out rather than via new_session_path: after a request into the
    # engine the test's own helpers resolve against the engine's routes too,
    # which would look for /jobs/session/new.
    assert_redirected_to "/session/new"
  end

  test "a signed-in admin reaches the dashboard without a basic auth prompt" do
    sign_in_as(users(:one))

    get mission_control_jobs.root_url

    # Not :unauthorized, which is what the gem returns when its basic auth is
    # left enabled but unconfigured.
    assert_response :success
  end

  test "the app nav links to the dashboard" do
    sign_in_as(users(:one))

    get locations_url # one of the few screens that shows the app nav

    assert_select "nav a[href=?]", mission_control_jobs.root_path, text: "Jobs"
  end
end
