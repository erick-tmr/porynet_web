require "test_helper"
require "capybara/cuprite"

Capybara.default_max_wait_time = 2
Capybara.disable_animation     = true
Capybara.save_path             = Rails.root.join("tmp/screenshots")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  parallelize(workers: 1)

  setup do
    Warden.test_mode!
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
    Warden.test_reset!
  end

  def login_as_user(user)
    login_as(user, scope: :user)
  end

  # Modes and progress live in localStorage, which Capybara does not reset between examples. Left
  # alone, a test that flips a switch decides what the next one starts from, and the pair passes or
  # fails on the seed.
  teardown do
    page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http")
  end

  # Clicking a mode switch races Stimulus: the button is in the HTML before the controller that
  # binds it, so an early click is silently dropped. A test that only needs the mode on says so
  # through the store the switch itself writes, then loads the page with it already set.
  def visit_with_modes(path, *modes)
    visit path
    state = { v: 1, living: {}, oak: {} }.merge(modes.index_with { { "yellow" => true } })
    page.execute_script("window.localStorage.setItem('porynet.modes', arguments[0])", state.to_json)
    visit path
  end

  # `pending_connection_errors` makes Cuprite raise when a navigation finishes with requests still
  # in flight. Every page here asks R2 for thirty-odd sprites, which is more than any wait worth
  # setting will cover, so on a slow day that raise lands on whichever page happened to be slowest:
  # three different specs failed on three consecutive runs of the same green commit, each on a
  # sprite belonging to a page the change never touched. A slow image is not a broken page, and
  # nothing here asserts on one, so the run stops treating it as a failure. Capybara's own waiting
  # matchers still hold every assertion to `default_max_wait_time`.
  driven_by :cuprite, screen_size: [ 1400, 1000 ], options: {
    headless:                  ENV["HEADLESS"] != "0",
    process_timeout:           20,
    timeout:                   15,
    js_errors:                 true,
    pending_connection_errors: false,
    browser_options:           ENV["CI"] ? { "no-sandbox" => nil } : {}
  }
end
