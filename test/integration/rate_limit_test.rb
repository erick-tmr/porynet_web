require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  test "the login form stops an unattended run of guesses" do
    with_real_cache do
      10.times do
        post user_session_path, params: { user: { login: "ASH", password: "wrong-one" } }

        assert_response :unprocessable_content
      end

      post user_session_path, params: { user: { login: "ASH", password: "wrong-one" } }

      assert_response :too_many_requests
    end
  end

  test "asking for the reset link over and over stops too" do
    with_real_cache do
      5.times { post user_password_path, params: { user: { email: "ash@pallet.town" } } }

      post user_password_path, params: { user: { email: "ash@pallet.town" } }

      assert_response :too_many_requests
    end
  end

  private

  # The test environment runs a null store, where increment always answers nil and every limiter
  # waves the request through.
  def with_real_cache
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = previous
  end
end
