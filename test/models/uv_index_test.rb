require "test_helper"

class UvIndexTest < ActiveSupport::TestCase
  test "labels values by WHO exposure category" do
    assert_equal "Low", UvIndex.label_for(0)
    assert_equal "Low", UvIndex.label_for(2.9)
    assert_equal "Moderate", UvIndex.label_for(3)
    assert_equal "High", UvIndex.label_for(6)
    assert_equal "Very high", UvIndex.label_for(8)
    assert_equal "Extreme", UvIndex.label_for(11)
  end

  test "returns Unknown for a nil value" do
    assert_equal "Unknown", UvIndex.label_for(nil)
  end
end
