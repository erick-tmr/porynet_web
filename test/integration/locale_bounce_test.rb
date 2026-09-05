require "test_helper"

class LocaleBounceTest < ActionDispatch::IntegrationTest
  test "an English reader kept off the account page lands on the English login" do
    get account_path

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.failure.unauthenticated"), flash[:alert]
  end

  test "a Portuguese reader kept off the account page stays in Portuguese" do
    get "/pt/account"

    assert_redirected_to "/pt/login"
    assert_equal I18n.t("devise.failure.unauthenticated", locale: :pt), flash[:alert]
  end

  test "an unconfirmed sign-in is bounced back to the login it came from" do
    post user_session_path, params: { user: { login: "MISTY", password: "pikachu123" } }

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.failure.unconfirmed"), flash[:alert]
  end

  test "a signed-in reader turned away from the Portuguese forms stays in Portuguese" do
    post "/pt/login", params: { user: { login: "ASH", password: "pikachu123" } }

    assert_redirected_to "/pt/account"

    get "/pt/register"

    assert_redirected_to "/pt/account"

    get new_user_registration_path

    assert_redirected_to account_path
  end

  test "an unconfirmed sign-in in Portuguese is bounced to the Portuguese login" do
    post "/pt/login", params: { user: { login: "MISTY", password: "pikachu123" } }

    assert_redirected_to "/pt/login"
    assert_equal I18n.t("devise.failure.unconfirmed", locale: :pt), flash[:alert]
  end
end
