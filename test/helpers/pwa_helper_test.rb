require "test_helper"

class PwaHelperTest < ActiveSupport::TestCase
  # PwaHelper needs only asset_path, so give it one we control rather than
  # rebuilding assets to move the digest.
  class FakeView
    include PwaHelper

    attr_accessor :digests

    def initialize(digests)
      @digests = digests
    end

    def asset_path(name)
      "/assets/#{name.sub(/\.(\w+)\z/) { "-#{digests[name]}.#{$1}" }}"
    end
  end

  setup do
    @digests = { "application.js" => "aaa111", "application.css" => "bbb222" }
    @view = FakeView.new(@digests)
  end

  test "is a short hex digest, and the same every time it's asked" do
    assert_match(/\A[0-9a-f]{12}\z/, @view.service_worker_version)
    assert_equal @view.service_worker_version, @view.service_worker_version
  end

  # The whole point of deriving it from the digests: a new build rotates the
  # cache, and a deploy that only touched ERB leaves a good one alone.
  test "changes when a built asset does" do
    before = @view.service_worker_version

    @digests["application.js"] = "ccc333"
    assert_not_equal before, @view.service_worker_version

    @digests["application.js"] = "aaa111"
    assert_equal before, @view.service_worker_version

    @digests["application.css"] = "ddd444"
    assert_not_equal before, @view.service_worker_version
  end
end
