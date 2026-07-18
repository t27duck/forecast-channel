# Serializes locations into a GeoJSON FeatureCollection for the globe's symbol
# layer. Each feature carries the icon group (chosen from the weather code) and
# population, which the layer uses as a collision priority so larger cities win
# when markers overlap.
class LocationGeojson
  def self.feature_collection(locations)
    {
      type: "FeatureCollection",
      features: locations.map { |location| feature(location) }
    }
  end

  def self.feature(location)
    {
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [ location.longitude.to_f, location.latitude.to_f ]
      },
      properties: {
        name: location.name,
        icon: WeatherCode.icon_group(location.current_condition_code),
        population: location.population || 0
      }
    }
  end
end
