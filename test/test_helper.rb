require "simplecov"
require "undercover/simplecov_formatter"

SimpleCov.start "rails" do
  enable_coverage :branch
  skip "/test/"

  minimum_coverage(line: 100, branch: 100) unless ENV["SKIP_COVERAGE_FLOOR"]

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Undercover
  ])
end

SimpleCov.command_name("system") if ENV["SKIP_COVERAGE_FLOOR"]

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
