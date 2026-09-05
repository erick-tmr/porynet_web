require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  test "the login form stops an unattended run of guesses" do
    10.times do
      post user_session_path, params: { user: { login: "ASH", password: "wrong-one" } }

      assert_response :unprocessable_content
    end

    post user_session_path, params: { user: { login: "ASH", password: "wrong-one" } }

    assert_response :too_many_requests
  end

  test "asking for the reset link over and over stops too" do
    5.times { post user_password_path, params: { user: { email: "ash@pallet.town" } } }

    post user_password_path, params: { user: { email: "ash@pallet.town" } }

    assert_response :too_many_requests
  end

  test "sending the confirmation again stops too" do
    5.times { post user_confirmation_path, params: { user: { email: "misty@cerulean.gym" } } }

    post user_confirmation_path, params: { user: { email: "misty@cerulean.gym" } }

    assert_response :too_many_requests
  end

  test "a fresh visitor is not carrying the last one's count" do
    post user_session_path, params: { user: { login: "ASH", password: "pikachu123" } }

    assert_redirected_to account_path
  end
end
