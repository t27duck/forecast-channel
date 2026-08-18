module ApplicationHelper
  # What the calendar says today is, if it says anything (see SeasonalTheme).
  #
  # Takes a timezone because the occasion a visitor is having is the one where
  # they are, not the one on the server: Christmas morning in Auckland is still
  # Christmas Eve in Berlin. Falls back to the app's zone when there's no
  # location to go on, and when the stored name isn't one Rails knows.
  def seasonal_theme(timezone = nil)
    zone = timezone.present? ? Time.find_zone(timezone) : nil

    SeasonalTheme.for((zone || Time.zone).today)
  end
end
