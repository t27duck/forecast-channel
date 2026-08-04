class MapsController < ApplicationController
  allow_unauthenticated_access
  # The globe is a visitor screen, so it waits until they've told us where they
  # live; #markers is only data and stays open.
  before_action :require_current_location, only: %i[show]

  # How long a built marker feed may be reused. The features themselves only
  # change when weather is refreshed or a location is added or removed, which
  # the cache key covers — but each Current icon also follows its city's local
  # day/night (SolarPosition), which turns over with the clock and nothing else.
  # This is how late a sunrise or sunset can show on the globe.
  MARKERS_FRESH_FOR = 15.minutes

  # How many cities the "Tour" button flies between. Enough that a loop isn't
  # obviously repeating, few enough that each hop is a short one.
  TOUR_STOP_COUNT = 15

  def show
    @locations = Location.by_name
    # When arriving from a location's forecast, centre the globe on it.
    @focus = Location.find_by(slug: params[:location])
    # The biggest cities, put in route order: sorting by longitude walks the
    # tour eastward around the world rather than criss-crossing it. Two readable
    # steps rather than one clever query, on fifteen rows.
    @tour_stops = Location.most_populous(TOUR_STOP_COUNT).sort_by(&:longitude)
  end

  # GeoJSON feed of locations for the globe's symbol layer. Every visitor gets
  # identical bytes, so the serialized feed is cached rather than rebuilt on
  # each globe load — building it walks every location.
  def markers
    render json: Rails.cache.fetch(markers_cache_key, expires_in: MARKERS_FRESH_FOR) {
      LocationGeojson.feature_collection(Location.select(LocationGeojson::COLUMNS).by_name).to_json
    }
  end

  private

  # One COUNT/MAX(updated_at) query, so adding or removing a location and any
  # weather refresh both mint a new key. It has to be cache_key_with_version:
  # with collection_cache_versioning on (the Rails default) a relation's
  # cache_key is only the query signature, and the parts that actually move —
  # the count and the timestamp — live in its cache_version.
  def markers_cache_key
    [ "map/markers", Location.all.cache_key_with_version, (Time.current.to_i / MARKERS_FRESH_FOR.to_i) ]
  end
end
