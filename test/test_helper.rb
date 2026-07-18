ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Temporarily replace a class/singleton method with +replacement+ for the
    # duration of the block, restoring the original afterwards. Minitest 6
    # dropped the built-in +stub+, so we provide a minimal equivalent.
    def stub_singleton(klass, name, replacement)
      singleton = klass.singleton_class
      original = singleton.instance_method(name)
      singleton.define_method(name, &replacement)
      yield
    ensure
      singleton.define_method(name, original)
    end
  end
end
