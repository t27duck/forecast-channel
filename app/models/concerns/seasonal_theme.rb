# The handful of days in the year the app dresses up for, and nothing more.
#
# Deliberately a calendar rather than a stylesheet: it answers "what is today,
# if it's anything?" with a key, and each surface decides for itself what that
# key means to it — the splash swaps its suns for snowflakes at Christmas, the
# globe tints its atmosphere at Halloween. Adding an occasion here doesn't
# change anything on its own, which is the point: the decoration stays next to
# the thing being decorated.
#
# Occasions never overlap, so the first match wins and order is presentational.
module SeasonalTheme
  Theme = Struct.new(:key, :splash_message, keyword_init: true)

  OCCASIONS = [
    { key: "halloween", dates: [ [ 10, 31 ] ] },
    { key: "christmas", dates: [ [ 12, 24 ], [ 12, 25 ], [ 12, 26 ] ] },
    { key: "new_year",  dates: [ [ 12, 31 ], [ 1, 1 ] ], splash_message: "Happy New Year!" }
  ].freeze

  # The occasion the given date falls on, or nil on an ordinary day — which is
  # almost every day, so callers are expected to handle nil as the normal case.
  def self.for(date)
    return nil if date.nil?

    occasion = OCCASIONS.find { |candidate| candidate[:dates].include?([ date.month, date.day ]) }
    return nil if occasion.nil?

    Theme.new(key: occasion[:key], splash_message: occasion[:splash_message])
  end
end
