# Tells open screens that stored weather has moved on.
#
# What goes over the wire is a *signal*, never rendered HTML — the one thing
# Turbo Streams are usually for. It has to be: every weather view renders
# through `current_setting`, which reads the visitor's own signed temperature
# and wind cookies, and a broadcast renders outside any request, with no cookies
# to read. Streaming markup would therefore push whichever units the *server*
# defaulted to onto every listener and quietly break the °C/°F toggle. So the
# server only says "this changed" and the client re-fetches over HTTP, where its
# own cookies apply again.
#
# The matching client half is app/javascript/lib/stream_actions.js.
class WeatherBroadcast
  # A batch of locations was refreshed.
  def self.batch_refreshed
    marker_feed_changed
  end

  # A location was added, renamed, moved or removed. The marker feed carries
  # each location's name, slug, coordinates and population as well as its
  # weather, so CRUD changes what the globe should be drawing just as a refresh
  # does — and without this it wouldn't find out until the next hourly sweep.
  def self.locations_changed
    marker_feed_changed
  end

  # Ask the open management index to re-render itself. A Turbo page refresh
  # rather than a custom signal, because the rows show temperatures through the
  # visitor's own unit cookie: the client re-requests the page, so the answer is
  # in *their* units and Turbo morphs it in without losing scroll. Turbo
  # coalesces the refreshes a fanned-out sweep produces on its own.
  def self.index_refreshed
    Turbo::StreamsChannel.broadcast_refresh_to(Location::INDEX_STREAM)
  end

  # Ask this location's own forecast screen to re-render. A page refresh again,
  # and for the same reason as the index: the panels render temperatures and
  # wind through the reader's own cookies. The screen protects the bits it keeps
  # in JavaScript with data-turbo-permanent, so the morph reaches the panels and
  # the "As of" stamp and nothing else — see locations/show.
  def self.forecast_refreshed(location)
    Turbo::StreamsChannel.broadcast_refresh_to(location.forecast_stream)
  end

  # One location finished refreshing — what the splash is holding its beat for.
  def self.location_ready(location)
    Turbo::StreamsChannel.broadcast_action_to(
      location.weather_stream,
      action: :weather_ready,
      attributes: { slug: location.slug }
    )
  end

  # Both reasons above are the same instruction to the globe — re-read the whole
  # feed — so they share one signal; they're named apart at the call sites
  # because that's where the difference is worth reading. `version` busts any
  # conditional GET on /map/markers, whose response we've just invalidated.
  def self.marker_feed_changed
    Turbo::StreamsChannel.broadcast_action_to(
      Location::WEATHER_STREAM,
      action: :weather_refreshed,
      attributes: { version: Time.current.to_i }
    )
  end
  private_class_method :marker_feed_changed
end
