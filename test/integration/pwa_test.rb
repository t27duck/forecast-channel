require "test_helper"

# The PWA files are served by Rails::PwaController, which is not one of this
# app's controllers — it inherits Rails::ApplicationController, so the global
# require_authentication and the visitor screens' require_current_location both
# pass it by. That's what makes it work (a browser asks for the manifest before
# anyone has signed in or chosen anywhere), and it's exactly the kind of thing
# that gets "tidied up" into the app's own controller later. These pin it.
class PwaTest < ActionDispatch::IntegrationTest
  # An integration test starts with an empty cookie jar, which is precisely the
  # state under test: no session, no current_location_id. The negative control
  # is the point — without it this would still pass if the whole app were
  # accidentally opened up.
  test "the manifest is served to a visitor with no session and no chosen location" do
    get settings_url
    assert_redirected_to settings_location_path, "expected the app to be fail-closed in this request"

    get pwa_manifest_url(format: :json)
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "the manifest only names icons that are actually in public/" do
    get pwa_manifest_url(format: :json)
    manifest = response.parsed_body

    sources = manifest["icons"].map { |icon| icon["src"] }
    sources += manifest["shortcuts"].flat_map { |shortcut| shortcut["icons"].map { |icon| icon["src"] } }

    assert_predicate sources, :any?
    sources.uniq.each do |src|
      # script/build_icons.rb writes these and they're committed by hand, so
      # "edited the manifest, never re-ran the script" is the likely mistake.
      assert Rails.root.join("public", src.delete_prefix("/")).exist?,
        "#{src} is named in the manifest but missing from public/ — run `ruby script/build_icons.rb`"
    end
  end

  # Launching from the home screen lands on the splash, whose controller checks
  # weather_stale? and enqueues a refresh before handing over — so every launch
  # is a freshness check. Somewhere else would silently give that up.
  test "the manifest starts the installed app at the splash" do
    get pwa_manifest_url(format: :json)

    assert_equal root_path, response.parsed_body["start_url"]
    assert_equal root_path, response.parsed_body["scope"]
  end

  test "the layout links the manifest and names the theme colour" do
    get root_url
    assert_select "link[rel=manifest][href=?]", pwa_manifest_path(format: :json)
    assert_select "meta[name=theme-color][content=?]", "#103a86"
  end

  test "the service worker is served to a visitor with no session and no chosen location" do
    get pwa_service_worker_url
    assert_response :success
    assert_includes %w[text/javascript application/javascript], response.media_type

    # The template is ERB — if it were ever renamed back to a plain .js the raw
    # handler would serve the tags instead of running them.
    assert_no_match(/<%/, response.body)
  end

  # The path the registration hardcodes. Rename the route and this fails, rather
  # than every visitor quietly going unregistered.
  test "the service worker is at the path the registration asks for" do
    assert_equal "/service-worker", pwa_service_worker_path
  end

  test "the service worker names the current build" do
    get pwa_service_worker_url

    version = ApplicationController.helpers.service_worker_version
    assert_includes response.body, version
    assert_includes response.body, "forecast-assets-"
  end

  # A worker the browser is told to hold on to is a deploy nobody can push
  # through. Rails revalidates by default; this is here so it stays that way.
  test "the service worker is revalidated rather than held" do
    get pwa_service_worker_url

    cache_control = response.headers["Cache-Control"].to_s
    assert_includes cache_control, "max-age=0"
    assert_includes cache_control, "must-revalidate"
  end

  # Nothing else ever parses this file: esbuild bundles app/javascript, not
  # app/views, and a worker that won't parse fails at registration with nothing
  # on screen to show for it. Node is already a hard dependency (it builds the
  # bundles), so lean on it.
  test "the service worker is syntactically valid JavaScript" do
    get pwa_service_worker_url

    Tempfile.create([ "service-worker", ".js" ]) do |file|
      file.write(response.body)
      file.flush

      output = `node --check #{Shellwords.escape(file.path)} 2>&1`
      assert_predicate $?, :success?, "service worker doesn't parse:\n#{output}"
    end
  end

  test "the offline fallback page the worker caches is really there" do
    assert Rails.root.join("public", "offline.html").exist?
  end
end
