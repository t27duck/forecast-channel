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
end
