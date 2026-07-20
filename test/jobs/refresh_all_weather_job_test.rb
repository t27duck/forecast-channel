require "test_helper"

class RefreshAllWeatherJobTest < ActiveJob::TestCase
  test "enqueues batched refreshes covering every location" do
    assert_enqueued_jobs 1, only: RefreshWeatherBatchJob do
      RefreshAllWeatherJob.perform_now
    end

    assert_equal Location.ids.sort, enqueued_batch_ids.sort
  end

  private

  # Every location id across the enqueued batch jobs.
  def enqueued_batch_ids
    enqueued_jobs.select { |job| job["job_class"] == "RefreshWeatherBatchJob" }
      .flat_map { |job| job["arguments"].first }
  end
end
