# The Wii Forecast Channel's "Laundry Index" — how well washing will dry
# outdoors today. Derived from the current conditions we already store, so it
# needs no extra fetch: laundry dries best when it's warm, dry (low humidity),
# breezy, and — above all — not about to rain.
#
# This is a deliberately simple, transparent heuristic, not a meteorological
# model. Temperature and humidity are required; wind and rain refine the score
# when present.
module LaundryIndex
  Rating = Struct.new(:key, :label, :blurb, keyword_init: true)

  TIERS = [
    { min: 5,  key: "excellent", label: "Excellent", blurb: "Warm, dry and breezy — washing will dry in no time." },
    { min: 2,  key: "good",      label: "Good",      blurb: "A fine day to hang the washing out." },
    { min: -1, key: "fair",      label: "Fair",      blurb: "It'll dry, but slowly — give it time." }
  ].freeze
  POOR = { key: "poor", label: "Poor", blurb: "Best to dry laundry indoors today." }.freeze

  # Rain chance at or above this is decisive on its own — no drying outdoors.
  RAIN_IS_DECISIVE = 70

  def self.rating(temperature:, humidity:, wind_speed:, precipitation_probability:)
    return nil if temperature.nil? || humidity.nil?

    rain = precipitation_probability
    return build(POOR) if rain && rain.to_i >= RAIN_IS_DECISIVE

    score = temperature_score(temperature) + humidity_score(humidity) +
      wind_score(wind_speed) + rain_score(rain)

    build(TIERS.find { |tier| score >= tier[:min] } || POOR)
  end

  def self.build(tier)
    Rating.new(key: tier[:key], label: tier[:label], blurb: tier[:blurb])
  end
  private_class_method :build

  # Warmth speeds evaporation; cold stalls it.
  def self.temperature_score(temperature)
    case temperature.to_f
    when 24.. then 2
    when 16...24 then 1
    when ...6 then -2
    else 0
    end
  end
  private_class_method :temperature_score

  # Dry air pulls moisture out; muggy air holds it in.
  def self.humidity_score(humidity)
    case humidity.to_i
    when ..45 then 2
    when 46..65 then 1
    when 85.. then -2
    else 0
    end
  end
  private_class_method :humidity_score

  # A breeze carries moisture away; dead-still air doesn't. Unknown wind is
  # treated neutrally. Wind speed is in km/h.
  def self.wind_score(wind_speed)
    return 0 if wind_speed.nil?

    case wind_speed.to_f
    when 12.. then 1
    when ...4 then -1
    else 0
    end
  end
  private_class_method :wind_score

  # A low rain chance helps confidence; a moderate one hurts. A high chance is
  # handled decisively before scoring. Unknown chance is neutral.
  def self.rain_score(precipitation_probability)
    return 0 if precipitation_probability.nil?

    case precipitation_probability.to_i
    when ..10 then 2
    when 40..69 then -2
    else 0
    end
  end
  private_class_method :rain_score
end
