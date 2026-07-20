require "test_helper"

class RefreshWeatherTierJobTest < ActiveJob::TestCase
  test "enqueues batches for the hot tier only" do
    RefreshWeatherTierJob.perform_now("hot")
    assert_equal Location.hot.ids.sort, enqueued_batch_ids.sort
  end

  test "enqueues batches for the cold tier only" do
    RefreshWeatherTierJob.perform_now("cold")
    assert_equal Location.cold.ids.sort, enqueued_batch_ids.sort
  end

  test "the two tiers together cover every location, without overlap" do
    assert_equal Location.count, Location.hot.count + Location.cold.count
  end

  test "rejects an unknown tier" do
    assert_raises(ArgumentError) { RefreshWeatherTierJob.perform_now("everything") }
  end

  private

  def enqueued_batch_ids
    enqueued_jobs.select { |job| job["job_class"] == "RefreshWeatherBatchJob" }
      .flat_map { |job| job["arguments"].first }
  end
end
