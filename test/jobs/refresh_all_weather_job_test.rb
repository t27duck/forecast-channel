require "test_helper"

class RefreshAllWeatherJobTest < ActiveJob::TestCase
  test "enqueues a per-location refresh for every location" do
    assert_enqueued_jobs Location.count, only: RefreshLocationWeatherJob do
      RefreshAllWeatherJob.perform_now
    end
  end
end
