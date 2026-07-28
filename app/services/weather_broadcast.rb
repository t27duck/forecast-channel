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
  # A batch of locations was refreshed: the globe re-reads its whole marker
  # feed. `version` busts any conditional GET on /map/markers, whose response
  # we've just invalidated.
  def self.batch_refreshed
    Turbo::StreamsChannel.broadcast_action_to(
      Location::WEATHER_STREAM,
      action: :weather_refreshed,
      attributes: { version: Time.current.to_i }
    )
  end

  # One location finished refreshing — what the splash is holding its beat for.
  def self.location_ready(location)
    Turbo::StreamsChannel.broadcast_action_to(
      location.weather_stream,
      action: :weather_ready,
      attributes: { slug: location.slug }
    )
  end
end
