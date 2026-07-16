require "simplecov"
require "undercover/simplecov_formatter"

SimpleCov.start "rails" do
  enable_coverage :branch
  skip "/test/"

  # 100% floor — the suite refuses to pass below full line and branch coverage.
  # Combined with undercover (changed-line gate), this enforces both "every
  # changed line is tested" and "no regressions in existing coverage." Mark
  # genuinely untestable lines with `# :nocov:` and a comment explaining why.
  minimum_coverage(line: 100, branch: 100) unless ENV["SKIP_COVERAGE_FLOOR"]

  # HTML for humans + Undercover's JSON formatter (coverage/coverage.json), which
  # the `undercover` CLI reads to flag changed lines that lack test coverage.
  # SimpleCov also writes coverage/.last_run.json (total line/branch %) for the
  # PR summary.
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

    # Keep per-worker coverage results distinct, then merge on teardown.
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
