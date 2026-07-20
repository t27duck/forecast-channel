# Resolves a list of place queries into ready-to-paste `db/seeds.rb` rows using
# Open-Meteo's geocoding API, so new cities can be added with real coordinates
# rather than hand-typed data. The seed file bakes this data in statically, so
# this is only run when curating the city list — not at deploy or boot.
#
# Usage:  bin/rails runner script/fetch_seed_cities.rb
#
# Each entry is disambiguated by the country (and admin1/region, where given):
# among the matches we keep the most populous, which resolves cases like
# "Vancouver" (city vs. island) or a city name shared across several states.
# Edit WANTED to the cities you want, run, and paste the printed rows into
# db/seeds.rb. Idempotency there is by open_meteo_id, so order doesn't matter.

WANTED = [
  # Fill in the cities to resolve, e.g.:
  # { q: "Madison",   country: "United States", admin1: "Wisconsin" },
  # { q: "Vancouver", country: "Canada",        admin1: "British Columbia" },
  # { q: "Nagoya",    country: "Japan" },
].freeze

def best_match(results, want)
  matched = results.select do |result|
    result.country == want[:country] &&
      (want[:admin1].nil? || result.admin1 == want[:admin1])
  end
  matched = results if matched.empty? # fall back so misses are visible, not silent
  matched.max_by { |result| result.population.to_i }
end

def ruby_literal(value)
  value.nil? ? "nil" : value.inspect
end

def seed_row(match)
  "  { open_meteo_id: #{match.open_meteo_id}, " \
    "name: #{ruby_literal(match.name)}, " \
    "latitude: #{match.latitude}, longitude: #{match.longitude}, " \
    "country: #{ruby_literal(match.country)}, country_code: #{ruby_literal(match.country_code)}, " \
    "admin1: #{ruby_literal(match.admin1)}, timezone: #{ruby_literal(match.timezone)}, " \
    "elevation: #{match.elevation.nil? ? 'nil' : match.elevation.to_f}, " \
    "population: #{match.population.nil? ? 'nil' : match.population} },"
end

rows = WANTED.filter_map do |want|
  match = best_match(OpenMeteo::GeocodingClient.search(want[:q], count: 20), want)
  if match
    warn "ok  #{match.name}, #{match.admin1}, #{match.country} (pop #{match.population})"
    seed_row(match)
  else
    warn "!!  no result for #{want[:q]} (#{want[:country]})"
    nil
  end
end

puts "\n===== SEED ROWS ====="
puts rows.join("\n")
