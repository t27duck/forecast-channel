# The /jobs dashboard is admin-only, guarded by the same sign-in as the rest of
# the app rather than by the HTTP basic auth the gem ships with.
#
# Its controllers inherit from the class named here, and ApplicationController
# includes Authentication — whose global require_authentication before_action
# makes the whole app fail-closed — so the dashboard is protected by simply
# being part of the app, and a signed-out visitor is redirected to /session/new
# like anywhere else. That is also the gem's default base class; naming it
# explicitly keeps the reason visible next to the line that turns basic auth off.
#
# Set on MissionControl::Jobs directly, not on config.mission_control.jobs: the
# engine copies that config across in a before_initialize hook, which has
# already run by the time initializers like this one do.
MissionControl::Jobs.base_controller_class = "::ApplicationController"
MissionControl::Jobs.http_basic_auth_enabled = false
