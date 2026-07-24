require "test_helper"

class MapsHelperTest < ActionView::TestCase
  test "no token in the test environment, so the globe renders offline" do
    with_mapbox_token("pk.test") do
      assert_nil mapbox_token
    end
  end

  test "a flag nobody set doesn't blank the token" do
    # What `config.x` answers with for a key no environment assigned — an empty
    # options object, which is truthy. Dev and production are in exactly this
    # state, so a plain truth test here leaves them with no token at all.
    unset = ActiveSupport::OrderedOptions.new

    with_disabled_flag(unset) do
      with_mapbox_token("pk.test") do
        assert_equal "pk.test", mapbox_token
      end
    end
  end

  test "a blank MAPBOX_TOKEN counts as no token" do
    # What the example env files ship, and what an unfilled .env leaves behind.
    with_disabled_flag(ActiveSupport::OrderedOptions.new) do
      with_mapbox_token("") do
        assert_nil mapbox_token
      end
    end
  end

  private

  def with_disabled_flag(value)
    original = Rails.configuration.x.mapbox_token_disabled
    Rails.configuration.x.mapbox_token_disabled = value
    yield
  ensure
    Rails.configuration.x.mapbox_token_disabled = original
  end

  def with_mapbox_token(value)
    original = ENV["MAPBOX_TOKEN"]
    ENV["MAPBOX_TOKEN"] = value
    yield
  ensure
    ENV["MAPBOX_TOKEN"] = original
  end
end
