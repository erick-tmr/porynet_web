require "test_helper"

module Users
  class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
    test "the page names the inbox when it knows which one it is" do
      get new_user_confirmation_path(email: "misty@cerulean.gym")

      assert_response :success
      assert_select "[data-confirmation-email]", text: "misty@cerulean.gym"
      assert_select "input[type=hidden][name='user[email]'][value=?]", "misty@cerulean.gym"
      assert_select "input[type=email][name='user[email]']", count: 0
    end

    test "arriving without an address asks for one" do
      get new_user_confirmation_path

      assert_response :success
      assert_select "[data-confirmation-email]", count: 0
      assert_select "input[type=email][name='user[email]']"
    end

    test "sending the mail again keeps the address in the URL" do
      post user_confirmation_path, params: { user: { email: "misty@cerulean.gym" } }

      assert_redirected_to new_user_confirmation_path(email: "misty@cerulean.gym")
      assert_equal I18n.t("devise.confirmations.send_paranoid_instructions"), flash[:notice]
    end
  end
end
