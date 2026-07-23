require "test_helper"

class SoundTest < ActiveSupport::TestCase
  test "requires a known kind" do
    assert_predicate build_sound(kind: "elevator_music"), :invalid?
    assert_predicate build_sound(kind: nil), :invalid?
    assert_predicate build_sound(kind: "globe_night"), :valid?
  end

  test "allows only one sound per kind" do
    build_sound.save!

    duplicate = build_sound
    assert_predicate duplicate, :invalid?
    assert_includes duplicate.errors[:kind], "has already been taken"
  end

  test "requires an attached audio file" do
    sound = Sound.new(kind: "current_day")

    assert_predicate sound, :invalid?
    assert_includes sound.errors[:audio], "can't be blank"
  end

  test "rejects anything that isn't an MP3" do
    sound = build_sound
    sound.audio.attach(io: StringIO.new("nope"), filename: "track.wav", content_type: "audio/wav")

    assert_predicate sound, :invalid?
    assert_includes sound.errors[:audio], "must be an MP3 file"
  end

  test "by_kind keys every sound by its kind" do
    build_sound(kind: "current_day").save!
    build_sound(kind: "globe_night").save!

    by_kind = Sound.by_kind

    assert_equal %w[current_day globe_night], by_kind.keys.sort
    assert_predicate by_kind["current_day"].audio, :attached?
  end

  test "in_kind_order sorts by the jukebox's own order, not by id" do
    build_sound(kind: "globe_night").save!
    build_sound(kind: "current_day").save!

    assert_equal %w[current_day globe_night], Sound.in_kind_order.map(&:kind)
  end

  test "label names the zone and time of day" do
    assert_equal "Globe · Night", build_sound(kind: "globe_night").label
  end

  private

  def build_sound(kind: "current_day")
    Sound.new(kind: kind).tap do |sound|
      sound.audio.attach(
        io: file_fixture("track.mp3").open, filename: "track.mp3", content_type: "audio/mpeg"
      )
    end
  end
end
