module SoundsHelper
  # Each music kind mapped to a playable URL for the jukebox; kinds with no
  # upload are simply absent (the layout then renders a blank value, which the
  # controller ignores).
  #
  # Proxy URLs rather than redirects: the proxy controller streams with Range
  # support and caches forever, and the path is derived from the blob's stable
  # signed id — so it's byte-identical on every page, and the jukebox (which
  # only reassigns its source when the source changes) never restarts the track
  # on a Turbo navigation.
  def music_track_paths
    @music_track_paths ||= Sound.by_kind.filter_map { |kind, sound|
      [ kind, track_path(sound) ] if sound.audio.attached?
    }.to_h
  end

  def track_path(sound)
    rails_storage_proxy_path(sound.audio, only_path: true)
  end
end
