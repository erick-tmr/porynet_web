require "test_helper"
require "capybara/cuprite"

Capybara.default_max_wait_time = 2
Capybara.disable_animation     = true
Capybara.save_path             = Rails.root.join("tmp/screenshots")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome over CDP (Cuprite) — no Selenium/WebDriver. Run serial;
  # HEADLESS=0 shows the browser.
  parallelize(workers: 1)

  driven_by :cuprite, screen_size: [ 1400, 1000 ], options: {
    headless:        ENV["HEADLESS"] != "0",
    process_timeout: 20,
    timeout:         15,
    js_errors:       true,
    browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
  }
end
