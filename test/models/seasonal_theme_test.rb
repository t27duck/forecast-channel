require "test_helper"

class SeasonalThemeTest < ActiveSupport::TestCase
  test "an ordinary day is no occasion at all" do
    assert_nil SeasonalTheme.for(Date.new(2026, 6, 15))
  end

  test "nil date is no occasion" do
    assert_nil SeasonalTheme.for(nil)
  end

  test "Halloween is the 31st of October only" do
    assert_equal "halloween", SeasonalTheme.for(Date.new(2026, 10, 31)).key
    assert_nil SeasonalTheme.for(Date.new(2026, 10, 30))
    assert_nil SeasonalTheme.for(Date.new(2026, 11, 1))
  end

  test "Christmas covers the eve, the day and the day after" do
    (24..26).each do |day|
      assert_equal "christmas", SeasonalTheme.for(Date.new(2026, 12, day)).key
    end

    assert_nil SeasonalTheme.for(Date.new(2026, 12, 23))
    assert_nil SeasonalTheme.for(Date.new(2026, 12, 27))
  end

  test "New Year spans the turn of the year and carries its own splash message" do
    %w[2026-12-31 2027-01-01].each do |date|
      theme = SeasonalTheme.for(Date.parse(date))
      assert_equal "new_year", theme.key
      assert_equal "Happy New Year!", theme.splash_message
    end

    assert_nil SeasonalTheme.for(Date.new(2027, 1, 2))
  end

  test "occasions that have no message of their own leave it nil" do
    assert_nil SeasonalTheme.for(Date.new(2026, 12, 25)).splash_message
  end

  test "every occasion's dates are unique, so the first match is the only match" do
    dates = SeasonalTheme::OCCASIONS.flat_map { |occasion| occasion[:dates] }

    assert_equal dates.uniq, dates
  end
end
