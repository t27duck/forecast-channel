require "test_helper"

class SoundsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one)) # managing the music is admin-only
  end

  test "managing sounds requires signing in" do
    sign_out

    get sounds_url
    assert_redirected_to new_session_path

    get new_sound_url
    assert_redirected_to new_session_path

    assert_no_difference("Sound.count") do
      post sounds_url, params: { sound: { kind: "current_day", audio: uploaded_track } }
    end
    assert_redirected_to new_session_path
  end

  test "index lists the uploaded sounds" do
    create_sound(kind: "globe_day")

    get sounds_url

    assert_response :success
    assert_select "h1", "Sounds"
    assert_select "td", text: "Globe · Day"
    assert_select "a[href=?]", new_sound_path(kind: "current_day") # still-silent slot
  end

  test "index invites a first upload when there are none" do
    get sounds_url

    assert_response :success
    assert_select "a[href=?]", new_sound_path, text: "Upload your first track"
  end

  test "new renders a blank form" do
    get new_sound_url
    assert_response :success
    assert_select "input[type=file][name=?]", "sound[audio]"
  end

  test "create attaches the uploaded track" do
    assert_difference("Sound.count", 1) do
      post sounds_url, params: { sound: { kind: "current_night", audio: uploaded_track } }
    end

    assert_redirected_to sounds_url
    sound = Sound.find_by(kind: "current_night")
    assert_predicate sound.audio, :attached?
    assert_equal "track.mp3", sound.audio.filename.to_s
  end

  test "create without a file re-renders the form" do
    assert_no_difference("Sound.count") do
      post sounds_url, params: { sound: { kind: "current_day" } }
    end

    assert_response :unprocessable_entity
  end

  test "update replaces the track" do
    sound = create_sound
    original_blob_id = sound.audio.blob.id

    patch sound_url(sound), params: { sound: { audio: uploaded_track } }

    assert_redirected_to sounds_url
    assert_not_equal original_blob_id, sound.reload.audio.blob.id
  end

  test "update without a file keeps the existing track" do
    sound = create_sound
    blob_id = sound.audio.blob.id

    patch sound_url(sound), params: { sound: { kind: "globe_day", audio: "" } }

    assert_redirected_to sounds_url
    assert_equal "globe_day", sound.reload.kind
    assert_equal blob_id, sound.audio.blob.id
  end

  test "destroy removes the sound" do
    sound = create_sound

    assert_difference("Sound.count", -1) do
      delete sound_url(sound)
    end

    assert_redirected_to sounds_url
  end

  private

  def uploaded_track
    fixture_file_upload("track.mp3", "audio/mpeg")
  end

  def create_sound(kind: "current_day")
    Sound.create!(kind: kind, audio: uploaded_track)
  end
end
