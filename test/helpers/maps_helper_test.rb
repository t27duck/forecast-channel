require "test_helper"

class MapsHelperTest < ActionView::TestCase
  test "no token in the test environment, so the globe renders offline" do
    assert_nil mapbox_token
  end

  test "a flag nobody set doesn't blank the token" do
    # What `config.x` answers with for a key no environment assigned — an empty
    # options object, which is truthy. Dev and production are in exactly this
    # state, so a plain truth test here leaves them with no token at all.
    unset = ActiveSupport::OrderedOptions.new
    credentials = ActiveSupport::OrderedOptions.new.merge(mapbox_token: "pk.test")

    with_disabled_flag(unset) do
      stub_singleton(Rails.application, :credentials, ->(*) { credentials }) do
        assert_equal "pk.test", mapbox_token
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
end
