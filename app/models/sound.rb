# An uploaded background-music track. There is one record per "kind" — the
# combination of zone (the forecast screens vs the globe) and time of day that
# the jukebox picks between — each with a single MP3 attached.
#
# The layout hands the attached blobs' URLs to the jukebox Stimulus controller
# (see SoundsHelper#music_track_paths); a kind with no upload simply means no
# music for that slot.
class Sound < ApplicationRecord
  KINDS = %w[current_day current_night globe_day globe_night].freeze

  LABELS = {
    "current_day" => "Forecast · Day",
    "current_night" => "Forecast · Night",
    "globe_day" => "Globe · Day",
    "globe_night" => "Globe · Night"
  }.freeze

  CONTENT_TYPES = %w[audio/mpeg audio/mp3].freeze

  has_one_attached :audio

  validates :kind, presence: true, inclusion: { in: KINDS }, uniqueness: true
  validates :audio, presence: true
  validate :audio_must_be_an_mp3

  # Every sound keyed by its kind, with attachments preloaded — the layout looks
  # up all four on every page render.
  def self.by_kind
    with_attached_audio.index_by(&:kind)
  end

  # In KINDS order (the order the jukebox thinks in) rather than by id.
  def self.in_kind_order
    with_attached_audio.sort_by { |sound| KINDS.index(sound.kind) || KINDS.size }
  end

  def label
    LABELS.fetch(kind, kind)
  end

  private

  # Active Storage has no built-in content-type validator, so check the blob's
  # declared type ourselves and drop the attachment when it isn't an MP3.
  def audio_must_be_an_mp3
    return unless audio.attached?
    return if CONTENT_TYPES.include?(audio.content_type)

    errors.add(:audio, "must be an MP3 file")
    audio.purge_later if audio.persisted?
  end
end
