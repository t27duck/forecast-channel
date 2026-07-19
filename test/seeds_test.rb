require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "populates a curated set of world cities with geocoding data, idempotently" do
    Location.delete_all
    silence_warnings { Rails.application.load_seed }

    count = Location.count
    assert_operator count, :>=, 150
    assert_operator count, :<=, 250
    assert_equal WORLD_CITIES.length, count

    # No duplicate places baked into the data.
    ids = WORLD_CITIES.map { |city| city[:open_meteo_id] }
    assert_equal ids.length, ids.uniq.length

    # Identity fields are seeded; weather is left blank for the refresh job.
    tokyo = Location.find_by(name: "Tokyo")
    assert tokyo, "expected Tokyo among the seeds"
    assert tokyo.open_meteo_id.present?
    assert tokyo.timezone.present?
    assert_nil tokyo.current_temperature

    # Re-seeding updates in place rather than duplicating.
    silence_warnings { Rails.application.load_seed }
    assert_equal count, Location.count
  end
end
